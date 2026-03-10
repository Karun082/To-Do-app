import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

class NotificationService {
  NotificationService._();

  static const int _overdueScheduleCount = 72; // Approx 12h when interval is 10m.
  static const int _idStep = 9973;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    await _configureLocalTimezone();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    await ensurePermissions();
  }

  static Future<void> ensurePermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleForTask(Task task) async {
    if (task.notificationId == null || task.dueDate == null || task.dueTime == null) {
      return;
    }

    await cancel(task.notificationId);
    if (task.status == 'done') return;

    final parts = task.dueTime!.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final due = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      hour,
      minute,
    );
    final now = DateTime.now();
    final firstAt = due.isAfter(now) ? due : now.add(const Duration(seconds: 2));
    final repeatEvery = Duration(minutes: task.reminderOffset <= 0 ? 10 : task.reminderOffset);

    for (var i = 0; i < _overdueScheduleCount; i++) {
      final scheduleAt = firstAt.add(Duration(minutes: repeatEvery.inMinutes * i));
      await _scheduleWithFallback(
        id: _slotId(task.notificationId!, i),
        title: 'DailyChip Overdue',
        body: '${task.title} is overdue',
        when: tz.TZDateTime.from(scheduleAt, tz.local),
        payload: task.title,
      );
    }
  }

  static Future<void> cancel(int? id) async {
    if (id == null) return;
    for (var i = 0; i < _overdueScheduleCount; i++) {
      await _plugin.cancel(_slotId(id, i));
    }
  }

  static Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId != 'snooze_10') return;
    if (response.id == null) return;

    final title = response.payload ?? 'Task reminder';
    final scheduleAt = tz.TZDateTime.now(tz.local).add(
      const Duration(minutes: 10),
    );

    await _scheduleWithFallback(
      id: response.id!,
      title: 'DailyChip Overdue',
      body: '$title is still overdue',
      when: scheduleAt,
      payload: title,
    );
  }

  static int _slotId(int baseId, int slot) =>
      (baseId + (slot * _idStep)) & 0x7fffffff;

  static Future<void> scheduleTestNotification() async {
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _scheduleWithFallback(
      id: 900000001,
      title: 'DailyChip Test',
      body: 'Test notification from app (5s)',
      when: when,
      payload: 'test',
    );
  }

  static Future<void> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks_ch',
        'Task Reminders',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('snooze_10', 'Snooze 10m'),
        ],
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
