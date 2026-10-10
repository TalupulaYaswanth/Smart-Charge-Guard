import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  static BatteryService get instance => _instance;

  BatteryService._internal();

  static const MethodChannel _channel = MethodChannel('com.chargealarm.app/battery_alarm');
  final Battery _battery = Battery();

  bool _isProtectionActive = true;

  // Real-time UI notifiers
  final ValueNotifier<int> batteryLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isChargingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> alarmTriggeredNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isMonitoringNotifier = ValueNotifier<bool>(true);

  bool get isProtectionActive => _isProtectionActive;
  int get batteryLevel => batteryLevelNotifier.value;
  bool get isCharging => isChargingNotifier.value;
  bool get isServiceRunning => isMonitoringNotifier.value;

  Future<void> startForegroundMonitoring() => startMonitoring();
  Future<void> stopForegroundMonitoring() => stopMonitoring();
  void resetSessionTrigger() => resetAlarm();

  Future<void> initialize() async {
    // 1. Listen for callbacks from native Android Foreground Service
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onBatteryUpdate':
          final args = call.arguments as Map?;
          if (args != null) {
            final level = (args['level'] as num?)?.toInt() ?? batteryLevelNotifier.value;
            final isCharging = (args['isCharging'] as bool?) ?? isChargingNotifier.value;
            batteryLevelNotifier.value = level;
            isChargingNotifier.value = isCharging;
          }
          break;
        case 'onAlarmTriggered':
          alarmTriggeredNotifier.value = true;
          break;
        case 'onAlarmStopped':
          alarmTriggeredNotifier.value = false;
          break;
      }
    });

    // 2. Fetch initial status from native Android service
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (status != null) {
        final level = (status['batteryLevel'] as num?)?.toInt() ?? 0;
        final isCharging = (status['isCharging'] as bool?) ?? false;
        final isFiring = (status['isAlarmFiring'] as bool?) ?? false;
        final isMonitoring = (status['isMonitoring'] as bool?) ?? false;

        if (level > 0) {
          batteryLevelNotifier.value = level;
          isChargingNotifier.value = isCharging;
        }
        alarmTriggeredNotifier.value = isFiring;
        isMonitoringNotifier.value = isMonitoring;
      }
    } catch (e) {
      debugPrint('Error querying initial native status: $e');
    }

    // 3. Fallback battery check if native returned 0 initially
    if (batteryLevelNotifier.value == 0) {
      try {
        final level = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        batteryLevelNotifier.value = level;
        isChargingNotifier.value = (state == BatteryState.charging || state == BatteryState.full);
      } catch (e) {
        debugPrint('Fallback battery check error: $e');
      }
    }

    // 4. Load persisted preferences
    final prefs = await SharedPreferences.getInstance();
    _isProtectionActive = prefs.getBool('alarm_protection_enabled') ?? true;
    isMonitoringNotifier.value = _isProtectionActive;

    // 5. If protection active, start native foreground service
    if (_isProtectionActive) {
      await startMonitoring();
    }
  }

  /// Starts native background foreground service with wake lock for sleep-mode protection
  Future<void> startMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    final target = prefs.getInt('target_percentage') ?? 80;
    final platform = prefs.getString('music_platform') ?? 'Spotify';
    final uri = prefs.getString('music_uri') ?? '';

    try {
      await _channel.invokeMethod('startMonitoring', {
        'targetLevel': target,
        'musicPlatform': platform,
        'musicUri': uri,
      });
      isMonitoringNotifier.value = true;
    } catch (e) {
      debugPrint('Error starting native monitoring service: $e');
    }
  }

  /// Stops native foreground service
  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
      isMonitoringNotifier.value = false;
    } catch (e) {
      debugPrint('Error stopping native monitoring service: $e');
    }
  }

  /// Toggles master 80% protection alarm
  void setProtectionActive(bool active) async {
    _isProtectionActive = active;
    isMonitoringNotifier.value = active;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_protection_enabled', active);

    if (active) {
      await Permission.notification.request();
      await requestIgnoreBatteryOptimizations();
      await startMonitoring();
    } else {
      await stopMonitoring();
    }
  }

  /// Updates configured platform, URI, or target level and syncs to native service
  Future<void> updateConfig({int? targetLevel, String? musicPlatform, String? musicUri}) async {
    final prefs = await SharedPreferences.getInstance();
    if (targetLevel != null) await prefs.setInt('target_percentage', targetLevel);
    if (musicPlatform != null) await prefs.setString('music_platform', musicPlatform);
    if (musicUri != null) await prefs.setString('music_uri', musicUri);

    if (_isProtectionActive) {
      await startMonitoring();
    }
  }

  /// Tests alarm audio playback using native MediaPlayer
  Future<void> triggerMusicPlayback(String platform, String uriInput) async {
    try {
      await _channel.invokeMethod('testAlarm', {
        'musicPlatform': platform,
        'musicUri': uriInput,
      });
      alarmTriggeredNotifier.value = true;
    } catch (e) {
      debugPrint('Error testing alarm audio: $e');
    }
  }

  /// Stops ringing alarm
  Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod('stopAlarm');
      alarmTriggeredNotifier.value = false;
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  void resetAlarm() {
    stopAlarm();
  }

  /// Opens system Battery Optimization settings to whitelist ChargeAlarm from Doze killing
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final isIgnoring = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
      return isIgnoring;
    } catch (e) {
      debugPrint('Error requesting battery optimizations exemption: $e');
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    // cleanup
  }
}
