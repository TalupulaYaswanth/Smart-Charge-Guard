import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<BatteryState>? _stateSubscription;
  Timer? _pollingTimer;

  bool _isProtectionActive = false;
  bool _hasTriggeredForCurrentCycle = false;

  // Stream controllers to notify UI of real-time state changes
  final ValueNotifier<int> batteryLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isChargingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> alarmTriggeredNotifier = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    // Initialize notification channels
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'charge_alarm_high_priority',
      'Battery 80% Alarm',
      description: 'Alerts when battery charging reaches 80% threshold',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initial battery fetch
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      batteryLevelNotifier.value = level;
      isChargingNotifier.value = _isCharging(state);
    } catch (e) {
      debugPrint('Error getting initial battery stats: $e');
    }

    // Subscribe to native charging intent broadcasts
    _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
      isChargingNotifier.value = _isCharging(state);
      _evaluateThreshold();
    });

    // High-precision periodic polling (checks every 4 seconds)
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final level = await _battery.batteryLevel;
        batteryLevelNotifier.value = level;
        _evaluateThreshold();
      } catch (e) {
        debugPrint('Battery poll error: $e');
      }
    });

    // Load saved protection state
    final prefs = await SharedPreferences.getInstance();
    _isProtectionActive = prefs.getBool('alarm_protection_enabled') ?? true;
  }

  bool _isCharging(BatteryState state) {
    return state == BatteryState.charging || state == BatteryState.full;
  }

  void setProtectionActive(bool active) async {
    _isProtectionActive = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_protection_enabled', active);

    if (active) {
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
      _evaluateThreshold();
    }
  }

  bool get isProtectionActive => _isProtectionActive;

  void _evaluateThreshold() {
    final isCharging = isChargingNotifier.value;
    final level = batteryLevelNotifier.value;

    // Reset cycle trigger debounce if charger unplugged or level below 80%
    if (!isCharging || level < 80) {
      _hasTriggeredForCurrentCycle = false;
      alarmTriggeredNotifier.value = false;
      return;
    }

    // Exact trigger condition: Plugged In + Battery >= 80% + Not yet fired in this cycle
    if (_isProtectionActive && isCharging && level >= 80 && !_hasTriggeredForCurrentCycle) {
      _hasTriggeredForCurrentCycle = true;
      alarmTriggeredNotifier.value = true;
      _fire80PercentAlarm(level);
    }
  }

  Future<void> _fire80PercentAlarm(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final platform = prefs.getString('music_platform') ?? 'Spotify';
    final musicUri = prefs.getString('music_uri') ?? '';

    // 1. Show Heads-Up Alert Notification with full-screen intent
    const androidDetails = AndroidNotificationDetails(
      'charge_alarm_high_priority',
      'Battery 80% Alarm',
      channelDescription: 'Alerts when battery charging reaches 80% threshold',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      color: Color(0xFF00E676),
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
    );

    await _notifications.show(
      8080,
      '⚡ Battery Reached $level%!',
      'Unplug your charger to protect battery health. Opening $platform...',
      const NotificationDetails(android: androidDetails),
    );

    // 2. Launch external music app or audio stream via url_launcher
    await triggerMusicPlayback(platform, musicUri);
  }

  /// Triggers music playback via direct intent / URL scheme
  Future<void> triggerMusicPlayback(String platform, String uriInput) async {
    String launchTarget = '';

    switch (platform) {
      case 'Spotify':
        if (uriInput.trim().isNotEmpty) {
          // Supports Spotify URIs (spotify:track:xxx) or Web links
          launchTarget = uriInput.trim();
        } else {
          // Default energetic wake-up playlist on Spotify
          launchTarget = 'spotify:search:wake%20up%20energy';
        }
        break;

      case 'JioSaavn':
        if (uriInput.trim().isNotEmpty) {
          launchTarget = uriInput.trim();
        } else {
          // Default JioSaavn top songs launch
          launchTarget = 'jiosaavn://';
        }
        break;

      case 'Default Ringtone/URL':
      default:
        if (uriInput.trim().isNotEmpty) {
          launchTarget = uriInput.trim();
        } else {
          // Fallback high-fidelity web audio chime stream
          launchTarget = 'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg';
        }
        break;
    }

    try {
      final uri = Uri.parse(launchTarget);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for Spotify / JioSaavn if native app not installed: open Web player
        if (platform == 'Spotify') {
          await launchUrl(
            Uri.parse('https://open.spotify.com'),
            mode: LaunchMode.externalApplication,
          );
        } else if (platform == 'JioSaavn') {
          await launchUrl(
            Uri.parse('https://www.jiosaavn.com'),
            mode: LaunchMode.externalApplication,
          );
        } else {
          await launchUrl(
            Uri.parse('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'),
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching music player URI: $e');
    }
  }

  void resetAlarm() {
    _notifications.cancel(8080);
    alarmTriggeredNotifier.value = false;
  }

  void dispose() {
    _stateSubscription?.cancel();
    _pollingTimer?.cancel();
  }
}
