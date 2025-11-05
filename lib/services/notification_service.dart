// lib/services/notification_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }
      _initialized = true;
    } catch (_) {
      // No-op in unit tests/web
    }
  }

  Future<void> showNow({required String title, required String body, int id = 100}) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'dg_reminders',
      'Reminders',
      channelDescription: 'Activity and screen-time reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  Future<void> scheduleInactivityPeriodic(Duration period, {int id = 200}) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'dg_inactivity',
      'Inactivity',
      channelDescription: 'Inactivity periodic reminders',
      importance: Importance.defaultImportance,
    );
    const details = NotificationDetails(android: androidDetails);
    try {
      // Use periodicallyShow for simple periodic reminders
      await _plugin.periodicallyShow(
        id,
        'Keep your timeline fresh',
        'It\'s time to log your recent activities.',
        RepeatInterval.hourly, // We\'ll adjust by cancelling/rescheduling if needed
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
