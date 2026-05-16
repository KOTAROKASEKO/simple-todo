import 'dart:async';
import 'dart:convert';

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

class SuperImportantAlarmPayload {
  const SuperImportantAlarmPayload({
    required this.title,
    this.scheduledAtMillis,
  });

  final String title;
  final int? scheduledAtMillis;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<SuperImportantAlarmPayload> _alarmController =
      StreamController<SuperImportantAlarmPayload>.broadcast();

  /// Dart-side timers that re-fire super-important alarms while the app is
  /// actively running. This is the safety net for the Android 14+ case where
  /// the system-level full-screen intent is downgraded to a heads-up
  /// notification whenever the device is unlocked. Keyed by notification id
  /// so [cancelReminder] can clean them up.
  final Map<int, Timer> _superImportantTimers = <int, Timer>{};
  final Map<int, SuperImportantAlarmPayload> _superImportantPayloads =
      <int, SuperImportantAlarmPayload>{};

  bool _initialized = false;

  Stream<SuperImportantAlarmPayload> get superImportantAlarms =>
      _alarmController.stream;

  SuperImportantAlarmPayload? _parseAlarmPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final kind = decoded['kind'];
      if (kind != 'super_important_task_alarm') return null;
      final titleRaw = decoded['title'];
      final title =
          titleRaw is String && titleRaw.trim().isNotEmpty ? titleRaw.trim() : 'Task';
      final msRaw = decoded['scheduledAtMillis'];
      return SuperImportantAlarmPayload(
        title: title,
        scheduledAtMillis: msRaw is num ? msRaw.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }

  void _emitAlarmFromPayload(String? payload) {
    final parsed = _parseAlarmPayload(payload);
    if (parsed != null) {
      _alarmController.add(parsed);
    }
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders',
        'Task Reminders',
        description: 'Reminders for your tasks',
        importance: Importance.high,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders_urgent',
        'Super important task reminders',
        description:
            'Strong sound and vibration. Use sparingly for must-not-miss tasks.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'daily_check_ins',
        'Daily Check-ins',
        description: 'Reminders to review your todo list',
        importance: Importance.high,
      ),
    );
  }

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _emitAlarmFromPayload(response.payload);
      },
    );
    await _createAndroidChannels();
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _emitAlarmFromPayload(launchDetails?.notificationResponse?.payload);
    }
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

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    if (!_initialized) {
      await init();
    }
    return _requestPermission();
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (!_initialized) {
      await init();
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return false;
    }
    final enabled = await android.areNotificationsEnabled();
    return enabled == true;
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

  /// Converts a local [DateTime] to [tz.local] clock time.
  tz.TZDateTime _toTZDateTime(DateTime localTime) {
    return tz.TZDateTime.from(localTime, tz.local);
  }

  /// Schedules a reminder notification.
  /// Returns the notification id so it can be cancelled later if needed.
  ///
  /// When [superImportant] is true, Android uses a separate channel with
  /// max importance, alarm category, and alarm audio attributes; iOS uses
  /// a time-sensitive interruption level.
  Future<int?> scheduleReminder({
    required String taskTitle,
    required DateTime scheduledTime,
    bool superImportant = false,
  }) async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Running on web; skip local schedule');
      return null;
    }
    if (!_initialized) {
      await init();
    }
    if (!_initialized) {
      debugPrint('[NotificationService] Initialization failed; cannot schedule');
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

    final displayTitle = taskTitle.trim().isEmpty ? 'Task' : taskTitle.trim();

    debugPrint(
      '[NotificationService] Scheduling "$displayTitle" at $tzTime (id=$id)',
    );

    final scheduleMode = await _resolveScheduleMode();
    debugPrint('[NotificationService] Schedule mode: $scheduleMode');
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (superImportant && android != null) {
      await android.requestFullScreenIntentPermission();
    }

    final payload = superImportant
        ? jsonEncode(<String, dynamic>{
            'kind': 'super_important_task_alarm',
            'title': displayTitle,
            'scheduledAtMillis': scheduledTime.millisecondsSinceEpoch,
          })
        : null;

    final androidDetails = superImportant
        ? AndroidNotificationDetails(
            'task_reminders_urgent',
            'Super important task reminders',
            channelDescription:
                'Strong sound and vibration. Use sparingly for must-not-miss tasks.',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 400, 180, 400, 180, 600]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            styleInformation: BigTextStyleInformation(
              displayTitle,
              contentTitle: 'Task reminder',
            ),
          )
        : AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for your tasks',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              displayTitle,
              contentTitle: 'Task reminder',
            ),
          );

    await _plugin.zonedSchedule(
      id,
      displayTitle,
      'Reminder',
      tzTime,
      NotificationDetails(
        android: androidDetails,
        iOS: superImportant
            ? const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.timeSensitive,
              )
            : null,
      ),
      payload: payload,
      androidScheduleMode: scheduleMode,
    );

    if (superImportant) {
      _armSuperImportantDartTimer(
        id: id,
        scheduledTime: scheduledTime,
        payload: SuperImportantAlarmPayload(
          title: displayTitle,
          scheduledAtMillis: scheduledTime.millisecondsSinceEpoch,
        ),
      );
    }

    debugPrint('[NotificationService] Successfully scheduled notification');
    return id;
  }

  /// Starts (or replaces) a Dart-side timer that emits the alarm payload when
  /// [scheduledTime] is reached. This lets the app auto-open the full-screen
  /// alarm page while it is running, even on Android 14+ where the system
  /// may only show the heads-up notification (because the device is unlocked).
  void _armSuperImportantDartTimer({
    required int id,
    required DateTime scheduledTime,
    required SuperImportantAlarmPayload payload,
  }) {
    _superImportantTimers.remove(id)?.cancel();
    _superImportantPayloads[id] = payload;
    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) {
      return;
    }
    _superImportantTimers[id] = Timer(delay, () {
      _superImportantTimers.remove(id);
      _superImportantPayloads.remove(id);
      if (!_alarmController.isClosed) {
        _alarmController.add(payload);
      }
    });
  }

  /// Fires any stored super-important alarm whose scheduled time has already
  /// passed. Intended to be called when the app resumes from background in
  /// case the Dart [Timer] was suspended by the OS and never fired on time.
  void flushDueSuperImportantAlarms() {
    if (_superImportantPayloads.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = <int>[];
    _superImportantPayloads.forEach((id, payload) {
      final ts = payload.scheduledAtMillis;
      if (ts != null && ts <= now) {
        due.add(id);
      }
    });
    for (final id in due) {
      final payload = _superImportantPayloads.remove(id);
      _superImportantTimers.remove(id)?.cancel();
      if (payload != null && !_alarmController.isClosed) {
        _alarmController.add(payload);
      }
    }
  }

  /// Cancels a scheduled reminder and its in-app safety timer, if any.
  Future<void> cancelReminder(int id) async {
    _superImportantTimers.remove(id)?.cancel();
    _superImportantPayloads.remove(id);
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[NotificationService] Failed to cancel id=$id: $e');
    }
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
    if (kIsWeb) {
      debugPrint('[NotificationService] Skipping daily reminders on web');
      return;
    }
    if (!_initialized) {
      await init();
    }
    if (!_initialized) {
      debugPrint('[NotificationService] Skipping daily reminders: init failed');
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
