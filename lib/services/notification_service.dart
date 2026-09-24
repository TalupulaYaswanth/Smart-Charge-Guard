import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init({Function(String?)? onAction}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'stop_alarm' || response.payload == 'stop_alarm') {
          onAction?.call('stop_alarm');
        }
      },
    );

    // Create high-importance alarm notification channel
    const androidChannel = AndroidNotificationChannel(
      'charge_alarm_channel',
      'Battery Charge Alarms',
      description: 'Triggered when battery hits target charging percentage',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> showBatteryAlarmNotification({
    required int percentage,
    required String trackTitle,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'charge_alarm_channel',
      'Battery Charge Alarms',
      channelDescription: 'Triggered when battery hits target charging percentage',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      color: Color(0xFF00E676),
      actions: [
        AndroidNotificationAction(
          'stop_alarm',
          'STOP ALARM',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const details = NotificationSettings(android: androidDetails);

    await _notificationsPlugin.show(
      8080,
      '🔋 Battery Reached $percentage%!',
      'Unplug your charger to protect battery health. Playing: $trackTitle',
      const NotificationDetails(android: androidDetails),
      payload: 'stop_alarm',
    );
  }

  Future<void> cancelAlarmNotification() async {
    await _notificationsPlugin.cancel(8080);
  }
}
