import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const String _keyReminder1 = 'daily_check_reminder_1';
const String _keyReminder2 = 'daily_check_reminder_2';
const String _keyReminder3 = 'daily_check_reminder_3';
const int _id1 = 7001;
const int _id2 = 12001;
const int _id3 = 21001;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      debugPrint('[NotificationService] Android plugin not available');
      return false;
    }

    final granted = await android.requestNotificationsPermission();
    if (granted != true) {
      debugPrint('[NotificationService] Notification permission denied');
      return false;
    }

    return true;
  }

  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final exactGranted = await android.requestExactAlarmsPermission();
    if (exactGranted == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    debugPrint(
      '[NotificationService] Exact alarm permission not granted, '
      'falling back to inexact scheduling',
    );
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Converts a local [DateTime] to a [tz.TZDateTime] in UTC,
  /// using Dart's built-in timezone awareness instead of tz.local.
  tz.TZDateTime _toTZDateTime(DateTime localTime) {
    final utc = localTime.toUtc();
    return tz.TZDateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  /// Schedules a reminder notification.
  /// Returns the notification id so it can be cancelled later if needed.
  Future<int?> scheduleReminder({
    required String taskTitle,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb || !_initialized) {
      debugPrint('[NotificationService] Not initialized or running on web');
      return null;
    }

    final permitted = await _requestPermission();
    if (!permitted) return null;

    final id = scheduledTime.millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF;

    final tzTime = _toTZDateTime(scheduledTime);
    final now = _toTZDateTime(DateTime.now());

    debugPrint(
      '[NotificationService] Local time: $scheduledTime, '
      'UTC target: $tzTime, UTC now: $now',
    );

    if (!tzTime.isAfter(now)) {
      debugPrint('[NotificationService] Scheduled time is in the past');
      return null;
    }

    debugPrint(
      '[NotificationService] Scheduling "$taskTitle" at $tzTime (id=$id)',
    );

    final scheduleMode = await _resolveScheduleMode();
    debugPrint('[NotificationService] Schedule mode: $scheduleMode');

    await _plugin.zonedSchedule(
      id,
      'Task Reminder',
      taskTitle,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for your tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: scheduleMode,
    );

    debugPrint('[NotificationService] Successfully scheduled notification');
    return id;
  }

  DateTime _nextInstanceOfTime({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, hour, minute).toLocal();
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static TimeOfDay _defaultTime1() => const TimeOfDay(hour: 7, minute: 0);
  static TimeOfDay _defaultTime2() => const TimeOfDay(hour: 12, minute: 0);
  static TimeOfDay _defaultTime3() => const TimeOfDay(hour: 21, minute: 0);

  static String _timeToPref(TimeOfDay t) => '${t.hour}:${t.minute}';

  static TimeOfDay _prefToTime(String? s, TimeOfDay fallback) {
    if (s == null || s.isEmpty) return fallback;
    final parts = s.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    if (h < 0 || h > 23 || m < 0 || m > 59) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Returns the three daily reminder times (saved or defaults).
  Future<List<TimeOfDay>> getDailyReminderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      _prefToTime(prefs.getString(_keyReminder1), _defaultTime1()),
      _prefToTime(prefs.getString(_keyReminder2), _defaultTime2()),
      _prefToTime(prefs.getString(_keyReminder3), _defaultTime3()),
    ];
  }

  /// Saves the three daily reminder times (local prefs only).
  /// Server-side reminders are driven by Firestore todo/{uid}/settings/notifications.
  Future<void> setDailyReminderTimes(List<TimeOfDay> times) async {
    if (times.length < 3) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReminder1, _timeToPref(times[0]));
    await prefs.setString(_keyReminder2, _timeToPref(times[1]));
    await prefs.setString(_keyReminder3, _timeToPref(times[2]));
  }

  /// Schedules daily notifications at the saved times (or 7am, 12pm, 9pm).
  Future<void> scheduleDailyCheckReminders() async {
    if (kIsWeb || !_initialized) {
      debugPrint(
        '[NotificationService] Skipping daily reminders: not initialized or web',
      );
      return;
    }

    final permitted = await _requestPermission();
    if (!permitted) return;

    await _plugin.cancel(_id1);
    await _plugin.cancel(_id2);
    await _plugin.cancel(_id3);

    final times = await getDailyReminderTimes();
    final scheduleMode = await _resolveScheduleMode();

    Future<void> scheduleFixedTime({
      required int id,
      required int hour,
      required int minute,
    }) async {
      final localTime = _nextInstanceOfTime(hour: hour, minute: minute);
      final tzTime = _toTZDateTime(localTime);

      await _plugin.zonedSchedule(
        id,
        'Check your tasks',
        'Take a moment to review your todo list.',
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_check_ins',
            'Daily Check-ins',
            channelDescription: 'Reminders to review your todo list',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    await scheduleFixedTime(id: _id1, hour: times[0].hour, minute: times[0].minute);
    await scheduleFixedTime(id: _id2, hour: times[1].hour, minute: times[1].minute);
    await scheduleFixedTime(id: _id3, hour: times[2].hour, minute: times[2].minute);

    debugPrint(
      '[NotificationService] Scheduled daily check reminders at '
      '${times[0].hour}:${times[0].minute}, ${times[1].hour}:${times[1].minute}, '
      '${times[2].hour}:${times[2].minute}',
    );
  }
}
