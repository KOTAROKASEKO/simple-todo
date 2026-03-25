import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/models/task_model.dart';
import 'package:simpletodo/notification_service.dart';
import 'package:hive/hive.dart';
import 'package:simpletodo/services/task_store.dart';
import 'package:simpletodo/web_favicon_badge.dart';
import 'package:simpletodo/pages/add_journal_entry_page.dart';
import 'package:simpletodo/pages/add_mistake_page.dart';
import 'package:simpletodo/pages/add_task_page.dart';
import 'package:simpletodo/pages/mistake_analysis_page.dart';
import 'package:simpletodo/pages/view_journal_entry_page.dart';
import 'package:simpletodo/pages/edit_task_page.dart';
import 'package:simpletodo/pages/goal_planner_page.dart';
import 'package:simpletodo/pages/notification_settings_page.dart';
import 'package:simpletodo/pages/timer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

class _TaskChecklistItem {
  _TaskChecklistItem({required this.text, required this.isDone});

  final String text;
  final bool isDone;
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, required this.user});

  final User user;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> with WidgetsBindingObserver {
  static const bool _useServerPushReminders = true;
  late final CollectionReference<Map<String, dynamic>> _tasksRef;
  late final CollectionReference<Map<String, dynamic>> _focusTasksRef;
  late final CollectionReference<Map<String, dynamic>> _mistakesRef;
  late final CollectionReference<Map<String, dynamic>> _mistakeAnalysesRef;
  late final CollectionReference<Map<String, dynamic>> _journalRef;
  TaskStore? _taskStore;
  bool _taskStoreReady = false;
  Box<String>? _taskOrderBox;
  bool get _useHive => !kIsWeb;
  final ScrollController _dateListController = ScrollController();
  final TextEditingController _addTaskTitleController = TextEditingController();
  StreamSubscription<Uri?>? _widgetClickSubscription;
  late DateTime _selectedDate;
  late List<DateTime> _sliderDays;
  String _displayedMonth = '';
  int _bottomTabIndex = 0;
  bool _desktopRecurring = false;
  bool _desktopHasReminder = false;
  TimeOfDay? _desktopReminderTime;
  List<TextEditingController> _desktopChecklistControllers =
      [TextEditingController()];
  final Map<String, bool> _optimisticTaskDoneByKey = <String, bool>{};
  final Set<String> _pendingTaskToggleKeys = <String>{};
  bool _readingAloudBannerVisible = false;
  bool _readingAloudBannerShownThisSession = false;
  bool _readingAloudBannerScheduled = false;
  final ScrollController _taskListScrollController = ScrollController();
  bool _isDraggingTask = false;
  bool _mistakeSelectionMode = false;
  final Set<String> _selectedMistakeIds = <String>{};
  bool _isAnalyzingMistakes = false;
  /// null = show all journal entries; 'diary'|'work'|'life' = filter by category.
  String? _journalCategoryFilter;

  bool get _isAndroidWidgetSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _sliderDays = _buildSliderDays();
    _displayedMonth = _monthNameEnglish(_selectedDate.month);
    _tasksRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('tasks')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _focusTasksRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('focus_tasks')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _mistakesRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('mistakes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _mistakeAnalysesRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('mistake_analyses')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _journalRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('journal_entries')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    if (_useHive) {
      _taskStore = TaskStore(userId: widget.user.uid, tasksRef: _tasksRef);
      Future<void> initOrder() async {
        try {
          final box = await Hive.openBox<String>('task_order');
          if (mounted) setState(() => _taskOrderBox = box);
        } catch (_) {}
      }
      initOrder();
      _taskStore!.init().then((_) {
        if (mounted) setState(() => _taskStoreReady = true);
      });
    } else {
      _taskStoreReady = true;
    }
    WidgetsBinding.instance.addObserver(this);
    if (_isAndroidWidgetSupported) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetAction);
      _widgetClickSubscription = HomeWidget.widgetClicked.listen(
        _handleWidgetAction,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollDateSliderToSelected(animated: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _desktopChecklistControllers) {
      controller.dispose();
    }
    _taskStore = null;
    _addTaskTitleController.dispose();
    _dateListController.dispose();
    _taskListScrollController.dispose();
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAndroidWidgetSupported) {
      _syncTodayWidgetData();
    }
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _parseDayKey(String? dayKey) {
    if (dayKey == null) return null;
    final parts = dayKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _taskToggleKey(String taskId, DateTime date) {
    return '$taskId|${_dayKey(date)}';
  }

  bool _resolvedTaskDoneForDate(
    DocumentSnapshot<Map<String, dynamic>> doc,
    DateTime date,
  ) {
    return _resolvedTaskDoneForDateById(doc.id, doc.data() ?? {}, date);
  }

  bool _resolvedTaskDoneForDateById(
    String taskId,
    Map<String, dynamic> data,
    DateTime date,
  ) {
    final key = _taskToggleKey(taskId, date);
    final optimisticValue = _optimisticTaskDoneByKey[key];
    if (optimisticValue != null) {
      return optimisticValue;
    }
    return _isTaskDoneForDate(data, date);
  }

  bool _isTaskDoneForDate(Map<String, dynamic> data, DateTime date) {
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    if (!isRecurringDaily) {
      final checklist = _taskChecklistFromData(data);
      if (checklist.isNotEmpty) {
        return _isChecklistDone(checklist);
      }
      return (data['isDone'] as bool?) ?? false;
    }

    final key = _dayKey(date);
    if (_taskChecklistTextsFromData(data).isNotEmpty) {
      final checklist = _taskChecklistFromDataForDate(data, date);
      return _isChecklistDone(checklist);
    }

    final doneByDateRaw = data['doneByDate'];
    if (doneByDateRaw is Map) {
      final done = doneByDateRaw[key];
      if (done is bool) {
        return done;
      }
    }

    // Legacy fallback for old recurring docs before date-scoped completion.
    final legacyIsDone = (data['isDone'] as bool?) ?? false;
    final legacyDoneOn = data['lastResetOn'] as String?;
    return legacyIsDone && legacyDoneOn == key;
  }

  Future<void> _addTask() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AddTaskPage(
          dateLabel:
              '${_shortMonthName(_selectedDate.month)} ${_selectedDate.day}',
          onCreateTask: ({
            required String title,
            required bool isRecurringDaily,
            TimeOfDay? reminderTime,
            List<String>? checklistItems,
          }) =>
              _createTask(
            title: title,
            isRecurringDaily: isRecurringDaily,
            reminderTime: reminderTime,
            checklistItems: checklistItems,
          ),
        ),
      ),
    );
  }

  Future<void> _createTaskFromDesktopPanel() async {
    final checklistTexts = _normalizeChecklistTexts(
      _desktopChecklistControllers.map((c) => c.text).toList(),
    );
    final saved = await _createTask(
      title: _addTaskTitleController.text,
      isRecurringDaily: _desktopRecurring,
      reminderTime: _desktopHasReminder ? _desktopReminderTime : null,
      checklistItems: checklistTexts.isNotEmpty ? checklistTexts : null,
    );

    if (!saved) {
      return;
    }

    _addTaskTitleController.clear();
    setState(() {
      _desktopRecurring = false;
      _desktopHasReminder = false;
      _desktopReminderTime = null;
      for (final controller in _desktopChecklistControllers) {
        controller.dispose();
      }
      _desktopChecklistControllers = [TextEditingController()];
    });
  }

  Future<bool> _createTask({
    required String title,
    required bool isRecurringDaily,
    TimeOfDay? reminderTime,
    List<String>? checklistItems,
    bool initialIsDone = false,
    DateTime? dateOverride,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final targetDate = dateOverride ?? _selectedDate;
    final selectedDayKey = _dayKey(targetDate);
    final today = _dayKey(DateTime.now());
    final createdAt = Timestamp.now();

    final taskData = <String, dynamic>{
      'title': trimmed,
      'isDone': initialIsDone,
      'isRecurringDaily': isRecurringDaily,
      'dateKey': selectedDayKey,
      'lastResetOn': today,
      'createdAt': createdAt,
    };
    final normalizedChecklist = _normalizeChecklistTexts(checklistItems);
    if (normalizedChecklist.isNotEmpty) {
      taskData['checklist'] = normalizedChecklist
          .map(
            (itemText) => <String, dynamic>{'text': itemText, 'isDone': false},
          )
          .toList();
    }

    if (reminderTime != null) {
      var remindAt = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );
      if (isRecurringDaily && !remindAt.isAfter(DateTime.now())) {
        remindAt = remindAt.add(const Duration(days: 1));
      }
      taskData['reminderHour'] = reminderTime.hour;
      taskData['reminderMinute'] = reminderTime.minute;
      taskData['remindAt'] = Timestamp.fromDate(remindAt.toUtc());
      taskData['reminderPending'] = true;
    }

    if (reminderTime != null && !_useServerPushReminders) {
      _scheduleReminder(trimmed, _selectedDate, reminderTime);
    }

    try {
      if (_useHive && _taskStore != null) {
        await _taskStore!.addTask(taskData);
      } else {
        await _tasksRef.add(taskData);
      }
      _syncTodayWidgetData();
      return true;
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? 'No permission to write tasks. Update Firestore rules.'
                  : 'Failed to save task: ${e.message ?? e.code}',
            ),
          ),
        );
      }
      return false;
    }
  }

  List<String> _normalizeChecklistTexts(List<String>? rawItems) {
    if (rawItems == null || rawItems.isEmpty) {
      return const <String>[];
    }
    final seen = <String>{};
    final normalized = <String>[];
    for (final raw in rawItems) {
      final text = raw.trim();
      if (text.isEmpty) {
        continue;
      }
      if (seen.add(text.toLowerCase())) {
        normalized.add(text);
      }
    }
    return normalized;
  }

  List<String> _taskChecklistTextsFromData(Map<String, dynamic> data) {
    final raw = data['checklist'];
    if (raw is! List) {
      return const <String>[];
    }
    final texts = <String>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final text = (entry['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      texts.add(text);
    }
    return texts;
  }

  /// Per-day checklist completion for recurring daily tasks (see [checklistDoneByDate]).
  List<bool> _recurringChecklistDoneBoolsForDay(
    Map<String, dynamic> data,
    String dayKey,
    int itemCount,
  ) {
    final raw = data['checklistDoneByDate'];
    if (raw is Map && raw[dayKey] is List) {
      final list = (raw[dayKey] as List).map((e) => e == true).toList();
      if (list.length == itemCount) {
        return list;
      }
    }
    final doneByDateRaw = data['doneByDate'];
    if (doneByDateRaw is Map) {
      final d = doneByDateRaw[dayKey];
      if (d is bool) {
        return List<bool>.filled(itemCount, d);
      }
    }
    return List<bool>.filled(itemCount, false);
  }

  /// Checklist rows for [date], including per-day state for recurring daily tasks.
  List<_TaskChecklistItem> _taskChecklistFromDataForDate(
    Map<String, dynamic> data,
    DateTime date,
  ) {
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    if (!isRecurringDaily) {
      return _taskChecklistFromData(data);
    }
    final texts = _taskChecklistTextsFromData(data);
    if (texts.isEmpty) {
      return const <_TaskChecklistItem>[];
    }
    final dayKey = _dayKey(date);
    final bools = _recurringChecklistDoneBoolsForDay(data, dayKey, texts.length);
    return List.generate(
      texts.length,
      (i) => _TaskChecklistItem(text: texts[i], isDone: bools[i]),
    );
  }

  List<_TaskChecklistItem> _taskChecklistFromData(Map<String, dynamic> data) {
    final raw = data['checklist'];
    if (raw is! List) {
      return const <_TaskChecklistItem>[];
    }
    final items = <_TaskChecklistItem>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final text = (entry['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      final isDone = (entry['isDone'] as bool?) ?? false;
      items.add(_TaskChecklistItem(text: text, isDone: isDone));
    }
    return items;
  }

  bool _isChecklistDone(List<_TaskChecklistItem> checklist) {
    if (checklist.isEmpty) {
      return false;
    }
    return checklist.every((item) => item.isDone);
  }

  List<Map<String, dynamic>> _checklistToFirestore(
    List<_TaskChecklistItem> checklist,
  ) {
    return checklist
        .map(
          (item) => <String, dynamic>{'text': item.text, 'isDone': item.isDone},
        )
        .toList();
  }

  Future<void> _scheduleReminder(
    String taskTitle,
    DateTime date,
    TimeOfDay time,
  ) async {
    if (kIsWeb) {
      // On web we do not schedule native notifications; instead we surface
      // upcoming reminders via the browser tab icon badge.
      return;
    }
    final scheduledTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final notifId = await NotificationService.instance.scheduleReminder(
      taskTitle: taskTitle,
      scheduledTime: scheduledTime,
    );

    if (notifId == null && mounted) {
      final now = DateTime.now();
      final isPast = !scheduledTime.isAfter(now);
      final message = isPast
          ? 'Reminder time is in the past. Pick a future time.'
          : 'Could not schedule reminder. Check notification permissions.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  static const double _dateItemWidth = 68.0;

  List<DateTime> _buildSliderDays() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final endDay = DateTime(now.year, now.month + 3, 0);
    final dayCount = endDay.difference(firstDay).inDays + 1;
    return List<DateTime>.generate(
      dayCount,
      (index) => firstDay.add(Duration(days: index)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthNameEnglish(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _shortMonthName(int month) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  void _scrollDateSliderToSelected({required bool animated}) {
    if (!_dateListController.hasClients) return;
    final index = _sliderDays.indexWhere((d) => _isSameDay(d, _selectedDate));
    if (index < 0) return;
    final itemExtent = _dateItemWidth + 8;
    final centeredOffset =
        (index * itemExtent) -
        ((_dateListController.position.viewportDimension - _dateItemWidth) / 2);
    final offset = centeredOffset.clamp(
      0.0,
      _dateListController.position.maxScrollExtent,
    );
    if (animated) {
      _dateListController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _dateListController.jumpTo(offset);
    }
  }

  bool _shouldShowTaskForSelectedDate(Map<String, dynamic> data) {
    final selectedDayKey = _dayKey(_selectedDate);
    String? dateKey = data['dateKey'] as String?;
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;

    // For non-recurring tasks: show only on the task's date or later (never on earlier days).
    if (!isRecurringDaily) {
      // Legacy tasks may have no dateKey; use createdAt date so they don't show on every day.
      if (dateKey == null) {
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          dateKey = _dayKey(createdAt.toDate());
        } else if (createdAt != null) {
          final ms = (createdAt is int)
              ? createdAt
              : (createdAt is num) ? createdAt.toInt() : null;
          if (ms != null) {
            dateKey = _dayKey(DateTime.fromMillisecondsSinceEpoch(ms));
          }
        }
        if (dateKey == null) {
          return selectedDayKey == _dayKey(DateTime.now());
        }
      }
      if (dateKey.compareTo(selectedDayKey) > 0) {
        return false;
      }
      if (dateKey == selectedDayKey) {
        return true;
      }
      final isDone = (data['isDone'] as bool?) ?? false;
      return !isDone;
    }

    if (dateKey == null) {
      return true;
    }

    return dateKey.compareTo(selectedDayKey) <= 0;
  }

  Future<void> _toggleTask(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool value,
  ) async {
    if (_useHive) {
      await _toggleTaskById(doc.id, value);
      return;
    }
    final key = _taskToggleKey(doc.id, _selectedDate);
    if (_pendingTaskToggleKeys.contains(key)) return;
    setState(() {
      _pendingTaskToggleKeys.add(key);
      _optimisticTaskDoneByKey[key] = value;
    });
    final data = doc.data() ?? <String, dynamic>{};
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    final checklist = _taskChecklistFromData(data);
    try {
      if (!isRecurringDaily) {
        if (checklist.isEmpty) {
          await doc.reference.update(<String, dynamic>{'isDone': value});
        } else {
          final updatedChecklist = checklist
              .map((item) => _TaskChecklistItem(text: item.text, isDone: value))
              .toList();
          await doc.reference.update(<String, dynamic>{
            'checklist': _checklistToFirestore(updatedChecklist),
            'isDone': value,
          });
        }
      } else {
        final selectedKey = _dayKey(_selectedDate);
        final texts = _taskChecklistTextsFromData(data);
        if (texts.isEmpty) {
          await doc.reference.set(<String, dynamic>{
            'doneByDate': <String, dynamic>{selectedKey: value},
          }, SetOptions(merge: true));
        } else {
          final template = texts
              .map((t) => <String, dynamic>{'text': t, 'isDone': false})
              .toList();
          await doc.reference.set(<String, dynamic>{
            'checklist': template,
            'doneByDate': <String, dynamic>{selectedKey: value},
            'checklistDoneByDate': <String, dynamic>{
              selectedKey: List<bool>.filled(texts.length, value),
            },
          }, SetOptions(merge: true));
        }
      }
      await _syncTodayWidgetData();
      if (mounted) {
        setState(() {
        _pendingTaskToggleKeys.remove(key);
        _optimisticTaskDoneByKey.remove(key);
      });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _pendingTaskToggleKeys.remove(key);
          _optimisticTaskDoneByKey.remove(key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.message ?? e.code}')),
        );
      }
    }
  }

  Future<void> _toggleTaskById(String taskId, bool value) async {
    final task = _taskStore!.getTask(taskId);
    if (task == null) return;

    final key = _taskToggleKey(taskId, _selectedDate);
    if (_pendingTaskToggleKeys.contains(key)) {
      return;
    }

    setState(() {
      _pendingTaskToggleKeys.add(key);
      _optimisticTaskDoneByKey[key] = value;
    });

    final data = _taskStore!.taskToMap(task);
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    final checklist = _taskChecklistFromData(data);
    final wasDone = _resolvedTaskDoneForDateById(taskId, data, _selectedDate);
    if (!wasDone && value) {
      _playTaskDoneHaptic();
    }
    try {
      Map<String, dynamic> updateData;
      if (!isRecurringDaily) {
        if (checklist.isEmpty) {
          updateData = <String, dynamic>{'isDone': value};
        } else {
          final updatedChecklist = checklist
              .map(
                (item) =>
                    _TaskChecklistItem(text: item.text, isDone: value),
              )
              .toList();
          updateData = <String, dynamic>{
            'checklist': _checklistToFirestore(updatedChecklist),
            'isDone': value,
          };
        }
      } else {
        final selectedKey = _dayKey(_selectedDate);
        final texts = _taskChecklistTextsFromData(data);
        if (texts.isEmpty) {
          updateData = <String, dynamic>{
            'doneByDate': <String, dynamic>{selectedKey: value},
          };
        } else {
          updateData = <String, dynamic>{
            'checklist': texts
                .map((t) => <String, dynamic>{'text': t, 'isDone': false})
                .toList(),
            'doneByDate': <String, dynamic>{selectedKey: value},
            'checklistDoneByDate': <String, dynamic>{
              selectedKey: List<bool>.filled(texts.length, value),
            },
          };
        }
      }
      await _taskStore!.updateTask(taskId, updateData);
      await _syncTodayWidgetData();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingTaskToggleKeys.remove(key);
        _optimisticTaskDoneByKey.remove(key);
      });
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingTaskToggleKeys.remove(key);
        _optimisticTaskDoneByKey.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update task. Reverted: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  Future<void> _toggleChecklistItem(
    DocumentSnapshot<Map<String, dynamic>> doc,
    int index,
    bool value,
  ) async {
    if (_useHive) {
      await _toggleChecklistItemById(doc.id, index, value);
      return;
    }
    final data = doc.data() ?? <String, dynamic>{};
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    if (isRecurringDaily) {
      final texts = _taskChecklistTextsFromData(data);
      if (index < 0 || index >= texts.length) {
        return;
      }
      final dayKey = _dayKey(_selectedDate);
      final bools = List<bool>.from(
        _recurringChecklistDoneBoolsForDay(data, dayKey, texts.length),
      );
      bools[index] = value;
      final isDone = bools.every((e) => e);
      final template = texts
          .map((t) => <String, dynamic>{'text': t, 'isDone': false})
          .toList();
      final updateData = <String, dynamic>{
        'checklist': template,
        'checklistDoneByDate': <String, dynamic>{dayKey: bools},
        'doneByDate': <String, dynamic>{dayKey: isDone},
      };
      try {
        await doc.reference.update(flattenFirestoreUpdateData(updateData));
        await _syncTodayWidgetData();
      } on FirebaseException catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.message ?? e.code}')),
        );
      }
      return;
    }
    final checklist = _taskChecklistFromData(data);
    if (index < 0 || index >= checklist.length) return;
    final updatedChecklist = List<_TaskChecklistItem>.from(checklist);
    updatedChecklist[index] = _TaskChecklistItem(
      text: updatedChecklist[index].text,
      isDone: value,
    );
    final isDone = _isChecklistDone(updatedChecklist);
    final updateData = <String, dynamic>{
      'checklist': _checklistToFirestore(updatedChecklist),
      'isDone': isDone,
    };
    try {
      await doc.reference.update(flattenFirestoreUpdateData(updateData));
      await _syncTodayWidgetData();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _toggleChecklistItemById(
    String taskId,
    int index,
    bool value,
  ) async {
    final task = _taskStore!.getTask(taskId);
    if (task == null) return;

    final data = _taskStore!.taskToMap(task);
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    Map<String, dynamic> updateData;
    if (isRecurringDaily) {
      final texts = _taskChecklistTextsFromData(data);
      if (index < 0 || index >= texts.length) {
        return;
      }
      final dayKey = _dayKey(_selectedDate);
      final bools = List<bool>.from(
        _recurringChecklistDoneBoolsForDay(data, dayKey, texts.length),
      );
      bools[index] = value;
      final isDone = bools.every((e) => e);
      final template = texts
          .map((t) => <String, dynamic>{'text': t, 'isDone': false})
          .toList();
      updateData = <String, dynamic>{
        'checklist': template,
        'checklistDoneByDate': <String, dynamic>{dayKey: bools},
        'doneByDate': <String, dynamic>{dayKey: isDone},
      };
    } else {
      final checklist = _taskChecklistFromData(data);
      if (index < 0 || index >= checklist.length) {
        return;
      }

      final updatedChecklist = List<_TaskChecklistItem>.from(checklist);
      updatedChecklist[index] = _TaskChecklistItem(
        text: updatedChecklist[index].text,
        isDone: value,
      );
      final isDone = _isChecklistDone(updatedChecklist);

      updateData = <String, dynamic>{
        'checklist': _checklistToFirestore(updatedChecklist),
        'isDone': isDone,
      };
    }

    try {
      await _taskStore!.updateTask(taskId, updateData);
      await _syncTodayWidgetData();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update checklist item: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  void _playTaskDoneHaptic() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _syncTodayWidgetData() async {
    if (!_isAndroidWidgetSupported) {
      return;
    }

    final todayKey = _dayKey(DateTime.now());
    try {
      final snapshot = await _tasksRef
          .orderBy('createdAt', descending: true)
          .get();

      final docs =
          snapshot.docs.where((doc) {
            final data = doc.data();
            final dateKey = data['dateKey'] as String?;
            final isRecurringDaily =
                (data['isRecurringDaily'] as bool?) ?? false;
            if (!isRecurringDaily) {
              if (dateKey == null) {
                return true;
              }
              if (dateKey.compareTo(todayKey) > 0) {
                return false;
              }
              if (dateKey == todayKey) {
                return true;
              }
              final isDone = (data['isDone'] as bool?) ?? false;
              return !isDone;
            }
            if (dateKey == null) {
              return true;
            }
            return dateKey.compareTo(todayKey) <= 0;
          }).toList()..sort((a, b) {
            final aDone = _isTaskDoneForDate(a.data(), DateTime.now());
            final bDone = _isTaskDoneForDate(b.data(), DateTime.now());
            if (aDone != bDone) {
              return aDone ? 1 : -1;
            }
            final aCreated =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            final bCreated =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            return bCreated.compareTo(aCreated);
          });

      final widgetTasks = docs.take(100).toList();
      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');

      await HomeWidget.saveWidgetData<String>('today_uid', widget.user.uid);
      await HomeWidget.saveWidgetData<String>('today_title', 'Today');
      await HomeWidget.saveWidgetData<String>(
        'today_task_count',
        widgetTasks.length.toString(),
      );
      for (var i = 0; i < widgetTasks.length; i++) {
        final data = widgetTasks[i].data();
        final title = (data['title'] as String?) ?? 'Untitled task';
        final isDone = _isTaskDoneForDate(data, DateTime.now());
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_id',
          widgetTasks[i].id,
        );
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_title',
          title,
        );
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_toggle_done',
          isDone ? '0' : '1',
        );
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_is_done',
          isDone ? '1' : '0',
        );
        final isRecurring =
            (data['isRecurringDaily'] as bool?) ?? false;
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_is_recurring',
          isRecurring ? '1' : '0',
        );
      }
      await HomeWidget.saveWidgetData<String>(
        'today_updated_at',
        '$hour:$minute',
      );
      await HomeWidget.updateWidget(androidName: 'TodoTodayWidgetProvider');
    } catch (_) {
      // Ignore widget sync failures to keep app actions responsive.
    }
  }

  Future<void> _handleWidgetAction(Uri? uri) async {
    if (!_isAndroidWidgetSupported || uri == null) {
      return;
    }

    final host = uri.host.toLowerCase();
    if (host == 'add') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await _addTask();
        }
      });
      return;
    }

    if (host == 'toggle') {
      final taskId = uri.queryParameters['taskId'];
      final done = uri.queryParameters['done'] == '1';
      if (taskId == null || taskId.isEmpty) {
        return;
      }

      try {
        final taskRef = _tasksRef.doc(taskId);
        final taskSnap = await taskRef.get();
        if (!taskSnap.exists) {
          return;
        }
        final taskData = taskSnap.data() ?? <String, dynamic>{};
        final isRecurringDaily =
            (taskData['isRecurringDaily'] as bool?) ?? false;
        final checklist = _taskChecklistFromData(taskData);
        if (!isRecurringDaily) {
          if (checklist.isEmpty) {
            await taskRef.update(<String, dynamic>{'isDone': done});
          } else {
            final updatedChecklist = checklist
                .map(
                  (item) => _TaskChecklistItem(text: item.text, isDone: done),
                )
                .toList();
            await taskRef.update(<String, dynamic>{
              'checklist': _checklistToFirestore(updatedChecklist),
              'isDone': done,
            });
          }
        } else {
          final todayKey = _dayKey(DateTime.now());
          final texts = _taskChecklistTextsFromData(taskData);
          if (texts.isEmpty) {
            await taskRef.set(<String, dynamic>{
              'doneByDate': <String, dynamic>{todayKey: done},
            }, SetOptions(merge: true));
          } else {
            final template = texts
                .map((t) => <String, dynamic>{'text': t, 'isDone': false})
                .toList();
            await taskRef.set(<String, dynamic>{
              'checklist': template,
              'doneByDate': <String, dynamic>{todayKey: done},
              'checklistDoneByDate': <String, dynamic>{
                todayKey: List<bool>.filled(texts.length, done),
              },
            }, SetOptions(merge: true));
          }
        }
        await _syncTodayWidgetData();
      } on FirebaseException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Widget action failed: ${e.message ?? e.code}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _showTaskDetailSheetById(String taskId, HiveTask task) async {
    final data = _taskStore!.taskToMap(task);
    await _showTaskDetailSheetWithData(taskId, data);
  }

  Future<void> _showTaskDetailSheet(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _showTaskDetailSheetWithData(
      doc.id,
      doc.data() ?? <String, dynamic>{},
      firestoreDoc: doc,
    );
  }

  Future<void> _showTaskDetailSheetWithData(
    String taskId,
    Map<String, dynamic> data, {
    DocumentSnapshot<Map<String, dynamic>>? firestoreDoc,
  }) async {
    final initialTitle = (data['title'] as String?) ?? 'Untitled task';
    final initialChecklist =
        _taskChecklistFromDataForDate(data, _selectedDate);
    final initialIsDone = _isTaskDoneForDate(data, _selectedDate);
    final initialIsRecurringDaily =
        (data['isRecurringDaily'] as bool?) ?? false;
    final dateKey = (data['dateKey'] as String?) ?? '-';
    final initialReminderHour = data['reminderHour'] as int?;
    final initialReminderMinute = data['reminderMinute'] as int?;
    final initialReminderTime =
        (initialReminderHour != null && initialReminderMinute != null)
        ? TimeOfDay(hour: initialReminderHour, minute: initialReminderMinute)
        : null;
    final initialHasReminder = initialReminderTime != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var isDeleting = false;
        var displayedChecklist = List<_TaskChecklistItem>.from(initialChecklist);
        var displayedIsDone = initialIsDone;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Task detail',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (!context.mounted) return;
                              final editChecklist = displayedChecklist
                                  .map((e) => EditTaskChecklistItem(
                                        text: e.text,
                                        isDone: e.isDone,
                                      ))
                                  .toList();
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) => EditTaskPage(
                                    taskId: taskId,
                                    dateKey: dateKey,
                                    initialTitle: initialTitle,
                                    initialChecklist: editChecklist.isEmpty
                                        ? [EditTaskChecklistItem(text: '', isDone: false)]
                                        : editChecklist,
                                    initialIsRecurringDaily: initialIsRecurringDaily,
                                    initialHasReminder: initialHasReminder,
                                    initialReminderTime: initialReminderTime,
                                    onSave: ({
                                      required String title,
                                      required List<String> checklistTexts,
                                      required bool isRecurringDaily,
                                      required bool hasReminder,
                                      TimeOfDay? reminderTime,
                                    }) async {
                                      final normalizedChecklist =
                                          _normalizeChecklistTexts(checklistTexts);
                                      final isChecklistTask =
                                          normalizedChecklist.isNotEmpty;
                                      final updateData = <String, dynamic>{
                                        'title': title,
                                        'isRecurringDaily': isRecurringDaily,
                                        'checklist': isChecklistTask
                                            ? normalizedChecklist
                                                .map((text) => <String, dynamic>{
                                                      'text': text,
                                                      'isDone': false,
                                                    })
                                                .toList()
                                            : FieldValue.delete(),
                                        'isDone': isChecklistTask
                                            ? false
                                            : (data['isDone'] as bool?) ?? false,
                                      };
                                      if (isRecurringDaily) {
                                        if (!isChecklistTask) {
                                          updateData['checklistDoneByDate'] =
                                              FieldValue.delete();
                                        } else {
                                          final oldNormalized =
                                              _normalizeChecklistTexts(
                                            _taskChecklistTextsFromData(data),
                                          );
                                          if (oldNormalized.length !=
                                                  normalizedChecklist.length ||
                                              !listEquals(
                                                oldNormalized,
                                                normalizedChecklist,
                                              )) {
                                            updateData['checklistDoneByDate'] =
                                                FieldValue.delete();
                                          }
                                        }
                                      }
                                      if (hasReminder && reminderTime != null) {
                                        final reminderDate =
                                            _parseDayKey(dateKey) ?? _selectedDate;
                                        var remindAt = DateTime(
                                          reminderDate.year,
                                          reminderDate.month,
                                          reminderDate.day,
                                          reminderTime.hour,
                                          reminderTime.minute,
                                        );
                                        if (isRecurringDaily) {
                                          while (!remindAt.isAfter(
                                              DateTime.now())) {
                                            remindAt = remindAt
                                                .add(const Duration(days: 1));
                                          }
                                        }
                                        updateData['reminderHour'] =
                                            reminderTime.hour;
                                        updateData['reminderMinute'] =
                                            reminderTime.minute;
                                        updateData['remindAt'] =
                                            Timestamp.fromDate(
                                                remindAt.toUtc());
                                        updateData['reminderPending'] = true;
                                      } else {
                                        updateData['reminderHour'] =
                                            FieldValue.delete();
                                        updateData['reminderMinute'] =
                                            FieldValue.delete();
                                        updateData['remindAt'] =
                                            FieldValue.delete();
                                        updateData['reminderPending'] = false;
                                      }
                                      if (firestoreDoc != null) {
                                        await firestoreDoc.reference
                                            .update(updateData);
                                      } else {
                                        await _taskStore!.updateTask(
                                            taskId, updateData);
                                      }
                                      await _syncTodayWidgetData();
                                    },
                                    onDelete: () async {
                                      if (firestoreDoc != null) {
                                        await firestoreDoc.reference.delete();
                                      } else {
                                        await _taskStore!.deleteTask(taskId);
                                      }
                                      await _syncTodayWidgetData();
                                    },
                                  ),
                                ),
                              );
                            },
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        initialTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (displayedChecklist.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Checklist',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          ...displayedChecklist.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return CheckboxListTile(
                              value: item.isDone,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(item.text),
                              onChanged: (value) async {
                                final newValue = value ?? false;
                                if (context.mounted) {
                                  setSheetState(() {
                                    displayedChecklist[index] =
                                        _TaskChecklistItem(
                                      text: item.text,
                                      isDone: newValue,
                                    );
                                    displayedIsDone = displayedChecklist
                                        .every((e) => e.isDone);
                                  });
                                }
                                try {
                                  if (firestoreDoc != null) {
                                    await _toggleChecklistItem(
                                      firestoreDoc,
                                      index,
                                      newValue,
                                    );
                                  } else {
                                    await _toggleChecklistItemById(
                                      taskId,
                                      index,
                                      newValue,
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    setSheetState(() {
                                      displayedChecklist[index] =
                                          _TaskChecklistItem(
                                        text: item.text,
                                        isDone: !newValue,
                                      );
                                      displayedIsDone = displayedChecklist
                                          .every((e) => e.isDone);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to save checklist change',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          }),
                        ],
                      const SizedBox(height: 16),
                      Text('Date: $dateKey'),
                      Text(
                        initialIsRecurringDaily
                            ? 'Recurring: Daily'
                            : 'Recurring: No',
                      ),
                      Text(
                        initialReminderTime == null
                            ? 'Reminder: Off'
                            : 'Reminder: ${initialReminderTime.format(context)}',
                      ),
                      Text(displayedIsDone ? 'Status: Done' : 'Status: Not done'),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              if (firestoreDoc != null) {
                                await _toggleTask(firestoreDoc, !initialIsDone);
                              } else {
                                await _toggleTaskById(taskId, !initialIsDone);
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              initialIsDone ? 'Mark as undone' : 'Mark as done',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: const Text('Delete task?'),
                                        content: const Text(
                                          'This action cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(
                                                dialogContext,
                                              ).pop(false);
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              Navigator.of(
                                                dialogContext,
                                              ).pop(true);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirmed != true) {
                                    return;
                                  }

                                  setSheetState(() {
                                    isDeleting = true;
                                  });

                                  try {
                                    if (firestoreDoc != null) {
                                      await firestoreDoc.reference.delete();
                                    } else {
                                      await _taskStore!.deleteTask(taskId);
                                    }
                                    await _syncTodayWidgetData();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  } on FirebaseException catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete task: ${e.message ?? e.code}',
                                          ),
                                        ),
                                      );
                                    }
                                    setSheetState(() {
                                      isDeleting = false;
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                                child: Text(
                                  isDeleting ? 'Deleting...' : 'Delete task',
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskListFirestore() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tasksRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load tasks. Check Firebase setup.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where((doc) => _shouldShowTaskForSelectedDate(doc.data()))
            .toList()
          ..sort((a, b) {
            final aDone = _resolvedTaskDoneForDate(a, _selectedDate);
            final bDone = _resolvedTaskDoneForDate(b, _selectedDate);
            if (aDone != bDone) return aDone ? 1 : -1;
            final aOrder = (a.data()['order'] as num?)?.toDouble();
            final bOrder = (b.data()['order'] as num?)?.toDouble();
            final aOrderVal = aOrder ?? double.infinity;
            final bOrderVal = bOrder ?? double.infinity;
            if (aOrderVal != bOrderVal) return aOrderVal.compareTo(bOrderVal);
            final aMs =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bMs =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });

        if (kIsWeb) {
          final now = DateTime.now();
          final hasUpcoming = docs.any((doc) {
            final data = doc.data();
            final reminderHour = data['reminderHour'] as int?;
            final reminderMinute = data['reminderMinute'] as int?;
            final reminderPending =
                (data['reminderPending'] as bool?) ?? false;
            if (!reminderPending ||
                reminderHour == null ||
                reminderMinute == null) {
              return false;
            }
            final scheduled = DateTime(
              now.year,
              now.month,
              now.day,
              reminderHour,
              reminderMinute,
            );
            final diffMinutes = scheduled.difference(now).inMinutes;
            return diffMinutes >= 0 && diffMinutes <= 60;
          });
          webFaviconBadge.setHasAttention(hasUpcoming);
        }
        if (docs.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9EBF1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt_rounded, size: 34, color: Colors.grey.shade500),
                  const SizedBox(height: 10),
                  Text(
                    'No tasks for this day',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to add your first task',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF6F7685)),
                  ),
                ],
              ),
            ),
          );
        }
        void applyReorder(int oldIndex, int newIndex) {
          if (oldIndex == newIndex) return;
          final reordered = List<DocumentSnapshot<Map<String, dynamic>>>.from(docs);
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          final leftData = newIndex > 0 ? (reordered[newIndex - 1].data()) : null;
          final rightData = newIndex < reordered.length - 1
              ? (reordered[newIndex + 1].data())
              : null;
          final leftOrder =
              (leftData != null ? leftData['order'] as num? : null)?.toDouble();
          final rightOrder =
              (rightData != null ? rightData['order'] as num? : null)?.toDouble();
          double newOrder;
          if (leftOrder == null && rightOrder == null) {
            newOrder = 1000;
          } else if (leftOrder == null) {
            newOrder = rightOrder! - 1000;
          } else if (rightOrder == null) {
            newOrder = leftOrder + 1000;
          } else {
            newOrder = (leftOrder + rightOrder) / 2;
          }
          moved.reference.update(<String, dynamic>{'order': newOrder});
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (PointerMoveEvent e) {
            if (!_isDraggingTask || !_taskListScrollController.hasClients) return;
            final y = e.position.dy;
            final h = MediaQuery.of(context).size.height;
            const zoneHeight = 80.0;
            const scrollStep = 10.0;
            if (y < zoneHeight) {
              final newOffset = (_taskListScrollController.offset - scrollStep)
                  .clamp(0.0, _taskListScrollController.position.maxScrollExtent);
              _taskListScrollController.jumpTo(newOffset);
            } else if (y > h - zoneHeight) {
              final newOffset = (_taskListScrollController.offset + scrollStep)
                  .clamp(0.0, _taskListScrollController.position.maxScrollExtent);
              _taskListScrollController.jumpTo(newOffset);
            }
          },
          child: ListView.builder(
            controller: _taskListScrollController,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] as String?) ?? 'Untitled task';
            final checklist =
                _taskChecklistFromDataForDate(data, _selectedDate);
            final doneChecklistCount =
                checklist.where((item) => item.isDone).length;
            final isDone = _resolvedTaskDoneForDate(doc, _selectedDate);
            final isPendingToggle =
                _pendingTaskToggleKeys.contains(_taskToggleKey(doc.id, _selectedDate));
            final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;

            Widget tileContent(Widget child) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFFBFBFC) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: child,
                );

            final tile = ListTile(
              onTap: () => _showTaskDetailSheet(doc),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              leading: Checkbox(
                value: isDone,
                side: const BorderSide(color: Color(0xFFBBC2CF), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                activeColor: const Color(0xFF111111),
                onChanged: !isPendingToggle
                    ? (value) => _toggleTask(doc, value ?? false)
                    : null,
              ),
              title: Text(
                title,
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? const Color(0xFF8A90A0) : null,
                ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isRecurringDaily
                          ? const Color(0xFFE8EFFD)
                          : const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isRecurringDaily ? 'Daily' : 'One-time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isRecurringDaily
                            ? const Color(0xFF2D63D5)
                            : const Color(0xFF23844B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checklist.isNotEmpty
                          ? 'Checklist: $doneChecklistCount/${checklist.length} done'
                          : 'Task',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6F7685),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );

            return LongPressDraggable<String>(
              key: ValueKey(doc.id),
              data: doc.id,
              onDragStarted: () => setState(() => _isDraggingTask = true),
              onDragEnd: (_) => setState(() => _isDraggingTask = false),
              onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 28,
                  child: tileContent(tile),
                ),
              ),
              childWhenDragging: tileContent(Opacity(opacity: 0.4, child: tile)),
              child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  final oldIndex = docs.indexWhere((d) => d.id == details.data);
                  if (oldIndex < 0 || oldIndex == index) return;
                  applyReorder(oldIndex, index);
                },
                builder: (context, candidateData, rejectedData) {
                  final showDropSlot = candidateData.isNotEmpty && !candidateData.contains(doc.id);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDropSlot)
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF111111).withOpacity(0.25),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Drop here',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111111).withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      tileContent(tile),
                    ],
                  );
                },
              ),
            );
          },
        ),
      );
      },
    );
  }

  Widget _buildTaskList() {
    if (!_useHive) {
      return _buildTaskListFirestore();
    }
    if (!_taskStoreReady || _taskStore == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder<Box<HiveTask>>(
      valueListenable: _taskStore!.listenable,
      builder: (context, box, _) {
        final allTasks = _taskStore!.getAllTasks();
        final filtered = allTasks
            .where((t) => _shouldShowTaskForSelectedDate(_taskStore!.taskToMap(t)))
            .toList();
        final dateKey = _dayKey(_selectedDate);
        final orderIds = _taskOrderBox
            ?.get(dateKey)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList() ?? [];
        final tasks = filtered
          ..sort((a, b) {
            final aId = _taskStore!.getTaskId(a);
            final bId = _taskStore!.getTaskId(b);
            final aData = _taskStore!.taskToMap(a);
            final bData = _taskStore!.taskToMap(b);
            final aDone = _resolvedTaskDoneForDateById(aId, aData, _selectedDate);
            final bDone = _resolvedTaskDoneForDateById(bId, bData, _selectedDate);
            if (aDone != bDone) return aDone ? 1 : -1;
            final aOrder = orderIds.indexOf(aId);
            final bOrder = orderIds.indexOf(bId);
            final aOrderVal = aOrder < 0 ? orderIds.length : aOrder;
            final bOrderVal = bOrder < 0 ? orderIds.length : bOrder;
            if (aOrderVal != bOrderVal) return aOrderVal.compareTo(bOrderVal);
            final aCreated = a.createdAtMillis ?? 0;
            final bCreated = b.createdAtMillis ?? 0;
            return bCreated.compareTo(aCreated);
          });

        if (tasks.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9EBF1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 34,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No tasks for this day',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to add your first task',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6F7685),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        void applyReorder(int oldIndex, int newIndex) {
          if (oldIndex == newIndex) return;
          final reordered = List<HiveTask>.from(tasks);
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          final newOrderIds =
              reordered.map((t) => _taskStore!.getTaskId(t)).toList();
          _taskOrderBox?.put(dateKey, newOrderIds.join(','));
          setState(() {});
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (PointerMoveEvent e) {
            if (!_isDraggingTask || !_taskListScrollController.hasClients) return;
            final y = e.position.dy;
            final h = MediaQuery.of(context).size.height;
            const zoneHeight = 80.0;
            const scrollStep = 10.0;
            if (y < zoneHeight) {
              final newOffset = (_taskListScrollController.offset - scrollStep)
                  .clamp(0.0, _taskListScrollController.position.maxScrollExtent);
              _taskListScrollController.jumpTo(newOffset);
            } else if (y > h - zoneHeight) {
              final newOffset = (_taskListScrollController.offset + scrollStep)
                  .clamp(0.0, _taskListScrollController.position.maxScrollExtent);
              _taskListScrollController.jumpTo(newOffset);
            }
          },
          child: ListView.builder(
            controller: _taskListScrollController,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
            final task = tasks[index];
            final taskId = _taskStore!.getTaskId(task);
            final data = _taskStore!.taskToMap(task);
            final title = (data['title'] as String?) ?? 'Untitled task';
            final checklist =
                _taskChecklistFromDataForDate(data, _selectedDate);
            final doneChecklistCount =
                checklist.where((item) => item.isDone).length;
            final isDone = _resolvedTaskDoneForDateById(
              taskId,
              data,
              _selectedDate,
            );
            final isPendingToggle =
                _pendingTaskToggleKeys.contains(_taskToggleKey(taskId, _selectedDate));
            final isRecurringDaily =
                (data['isRecurringDaily'] as bool?) ?? false;

            Widget tileContent(Widget child) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFFBFBFC) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: child,
                );

            final tile = ListTile(
              onTap: () => _showTaskDetailSheetById(taskId, task),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              leading: Checkbox(
                value: isDone,
                side: const BorderSide(color: Color(0xFFBBC2CF), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                activeColor: const Color(0xFF111111),
                onChanged: !isPendingToggle
                    ? (value) => _toggleTaskById(taskId, value ?? false)
                    : null,
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF8A90A0)
                      : const Color(0xFF17181C),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isRecurringDaily
                            ? const Color(0xFFEAF2FF)
                            : const Color(0xFFEFFAF2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isRecurringDaily ? 'Daily' : 'One-time',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRecurringDaily
                              ? const Color(0xFF2D63D5)
                              : const Color(0xFF23844B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        checklist.isNotEmpty
                            ? 'Checklist: $doneChecklistCount/${checklist.length} done'
                            : 'Task',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6F7685),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            return LongPressDraggable<String>(
              key: ValueKey(taskId),
              data: taskId,
              onDragStarted: () => setState(() => _isDraggingTask = true),
              onDragEnd: (_) => setState(() => _isDraggingTask = false),
              onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 28,
                  child: tileContent(tile),
                ),
              ),
              childWhenDragging: tileContent(Opacity(opacity: 0.4, child: tile)),
              child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  final oldIndex =
                      tasks.indexWhere((t) => _taskStore!.getTaskId(t) == details.data);
                  if (oldIndex < 0 || oldIndex == index) return;
                  applyReorder(oldIndex, index);
                },
                builder: (context, candidateData, rejectedData) {
                  final showDropSlot = candidateData.isNotEmpty && !candidateData.contains(taskId);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDropSlot)
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF111111).withOpacity(0.25),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Drop here',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111111).withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      tileContent(tile),
                    ],
                  );
                },
              ),
            );
          },
        ),
      );
      },
    );
  }

  Widget _buildDesktopAddPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create task',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Keep it simple and focused.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6F7685)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addTaskTitleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Task title'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Checklist',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _desktopChecklistControllers.add(
                      TextEditingController(),
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
            ],
          ),
          ..._desktopChecklistControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (controller.text.trim().isEmpty) {
                          return;
                        }
                        setState(() {
                          _desktopChecklistControllers.add(
                            TextEditingController(),
                          );
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Checklist item ${index + 1}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete checklist item',
                    onPressed: () {
                      setState(() {
                        if (_desktopChecklistControllers.length == 1) {
                          _desktopChecklistControllers.first.clear();
                        } else {
                          final removed =
                              _desktopChecklistControllers.removeAt(index);
                          removed.dispose();
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF8A90A0),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _desktopRecurring,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF111111),
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onChanged: (value) {
              setState(() {
                _desktopRecurring = value ?? false;
              });
            },
            title: const Row(
              children: [
                Icon(Icons.repeat_rounded, size: 18),
                SizedBox(width: 6),
                Text('Repeat daily'),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _desktopHasReminder,
            activeThumbColor: const Color(0xFF111111),
            onChanged: (value) {
              setState(() {
                _desktopHasReminder = value;
                if (value && _desktopReminderTime == null) {
                  _desktopReminderTime = const TimeOfDay(hour: 9, minute: 0);
                }
              });
            },
            title: const Text('Add reminder'),
          ),
          if (_desktopHasReminder)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 19,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _desktopReminderTime ??
                            const TimeOfDay(hour: 9, minute: 0),
                        initialEntryMode: TimePickerEntryMode.input,
                      );
                      if (picked != null) {
                        setState(() {
                          _desktopReminderTime = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        border: Border.all(color: const Color(0xFFE1E4EA)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _desktopReminderTime?.format(context) ?? '9:00 AM',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _createTaskFromDesktopPanel,
            child: const Text('Create task'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSlider(DateTime now) {
    return SizedBox(
      height: 74,
      child: ListView.builder(
        controller: _dateListController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _sliderDays.length,
        itemBuilder: (context, index) {
          final day = _sliderDays[index];
          final isSelected = _isSameDay(day, _selectedDate);
          final isToday = _isSameDay(day, now);
          final isFirstOfMonth = day.day == 1 && day.month != now.month;

          return Tooltip(
            message: '${_shortMonthName(day.month)} ${day.day}',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _displayedMonth = _monthNameEnglish(day.month);
                });
                _scrollDateSliderToSelected(animated: true);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: _dateItemWidth,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF111111) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF111111)
                          : isToday
                              ? const Color(0xFF8A93A8)
                              : const Color(0xFFE7EAF0),
                      width: isToday && !isSelected ? 1.2 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isFirstOfMonth)
                        Text(
                          _shortMonthName(day.month),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white70
                                : const Color(0xFF8A90A0),
                          ),
                        ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: isFirstOfMonth ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? const Color(0xFF17181C)
                                  : const Color(0xFF6F7685),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodoTabBody({required bool isDesktopWeb, required DateTime now}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const SizedBox(height: 6),
            _buildDateSlider(now),
            const SizedBox(height: 8),
            Expanded(
              child: isDesktopWeb
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: _buildTaskList()),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 360,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 20,
                                  right: 14,
                                ),
                                child: _buildDesktopAddPanel(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildTaskList(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
          'Are you sure you want to log out? Local cache will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _logoutAndClearCache();
  }

  Future<void> _logoutAndClearCache() async {
    if (!kIsWeb) {
      try {
        if (Hive.isBoxOpen('tasks')) {
          await Hive.box<dynamic>('tasks').close();
        }
        await Hive.deleteBoxFromDisk('tasks');
      } catch (_) {}
      try {
        if (Hive.isBoxOpen('task_order')) {
          await Hive.box<dynamic>('task_order').close();
        }
        await Hive.deleteBoxFromDisk('task_order');
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
    }
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Set notification'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatAnalysisDate(dynamic createdAt) {
    if (createdAt == null) return '';
    if (createdAt is Timestamp) {
      final d = createdAt.toDate();
      return '${_shortMonthName(d.month)} ${d.day}, ${d.year}';
    }
    return '';
  }

  Widget _buildAnalysisHistoryDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'AI analysis history',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _mistakeAnalysesRef
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No analyses yet. Select mistakes and tap the AI button to analyze.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final createdAt = data['createdAt'];
                      final content = data['content'] is String
                          ? data['content'] as String
                          : '';
                      final preview = content.length > 60
                          ? '${content.substring(0, 60).trim()}…'
                          : content;
                      final dateLabel = _formatAnalysisDate(createdAt).isEmpty
                          ? 'Analysis'
                          : _formatAnalysisDate(createdAt);
                      return ListTile(
                        title: Text(
                          dateLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        subtitle: preview.isEmpty
                            ? null
                            : Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => MistakeAnalysisPage(
                                analysesRef: _mistakeAnalysesRef,
                                initialAnalysisId: doc.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakesTabBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mistakesRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No mistakes recorded yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF6F7685),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a mistake and reflect on how to prevent it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6F7685),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            if (_mistakeSelectionMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFFFF3E0),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_rounded,
                        size: 18, color: Color(0xFFD35400)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMistakeIds.length > 1
                            ? 'Selected ${_selectedMistakeIds.length} mistakes. Tap the AI button to analyze.'
                            : 'Tap mistakes to select at least two for AI analysis.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F4D1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final id = doc.id;
                  final what = data['what'] as String? ?? '';
                  final why = data['why'] as String? ?? '';
                  final howToPrevent = data['howToPrevent'] as String? ?? '';
                  final isSelected = _selectedMistakeIds.contains(id);

                  Widget card = Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: _mistakeSelectionMode && isSelected
                          ? const BorderSide(color: Color(0xFF4A90D9), width: 2)
                          : BorderSide.none,
                    ),
                    color: _mistakeSelectionMode && isSelected
                        ? const Color(0xFFE8F3FF)
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_mistakeSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, top: 2),
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedMistakeIds.remove(id);
                                    } else {
                                      _selectedMistakeIds.add(id);
                                    }
                                  });
                                },
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  what,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (why.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Why: $why',
                                    style: const TextStyle(
                                      color: Color(0xFF6F7685),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                if (howToPrevent.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Prevent: $howToPrevent',
                                    style: const TextStyle(
                                      color: Color(0xFF4A90D9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (_mistakeSelectionMode) {
                    card = InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedMistakeIds.remove(id);
                          } else {
                            _selectedMistakeIds.add(id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: card,
                    );
                  }

                  return card;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJournalTabBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _journalRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No entries yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF5F6778),
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to write your first journal entry.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A90A0),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final filteredDocs = _journalCategoryFilter == null
            ? docs
            : docs
                .where((d) =>
                    ((d.data()['category'] as String?) ?? 'diary')
                        .toLowerCase() ==
                    _journalCategoryFilter)
                .toList();

        double orderForDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final data = d.data();
          final order = data['order'];
          if (order is num) return order.toDouble();
          final createdAt = data['createdAt'] as Timestamp?;
          return (createdAt?.millisecondsSinceEpoch ?? 0).toDouble();
        }

        filteredDocs.sort((a, b) {
          final oA = orderForDoc(a);
          final oB = orderForDoc(b);
          return oB.compareTo(oA);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _JournalCategoryFilterChip(
                    icon: Icons.view_list,
                    isSelected: _journalCategoryFilter == null,
                    onTap: () =>
                        setState(() => _journalCategoryFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _JournalCategoryFilterChip(
                    icon: Icons.book_outlined,
                    isSelected: _journalCategoryFilter == 'diary',
                    onTap: () =>
                        setState(() => _journalCategoryFilter = 'diary'),
                  ),
                  const SizedBox(width: 8),
                  _JournalCategoryFilterChip(
                    icon: Icons.work_outline,
                    isSelected: _journalCategoryFilter == 'work',
                    onTap: () =>
                        setState(() => _journalCategoryFilter = 'work'),
                  ),
                  const SizedBox(width: 8),
                  _JournalCategoryFilterChip(
                    icon: Icons.favorite_border,
                    isSelected: _journalCategoryFilter == 'life',
                    onTap: () =>
                        setState(() => _journalCategoryFilter = 'life'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _journalCategoryFilter == null
                          ? 'All'
                          : _journalCategoryFilter == 'diary'
                              ? 'Diary'
                              : _journalCategoryFilter == 'work'
                                  ? 'Work'
                                  : 'Life',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredDocs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _journalCategoryFilter == null
                              ? 'No entries yet'
                              : 'No ${_journalCategoryFilter == 'diary' ? 'Diary' : _journalCategoryFilter == 'work' ? 'Work' : 'Life'} entries',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  _reorderJournalEntry(filteredDocs, oldIndex, newIndex);
                },
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data();
                  final content = data['content'] as String? ?? '';
                  final category =
                      (data['category'] as String?)?.toLowerCase() ?? 'diary';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null
                      ? _formatJournalDate(createdAt.toDate())
                      : '';
                  final preview = content.length > 120
                      ? '${content.substring(0, 120).trim()}...'
                      : content;
                  final categoryIcon = category == 'work'
                      ? Icons.work_outline
                      : category == 'life'
                          ? Icons.favorite_border
                          : Icons.book_outlined;
                  final categoryBadge = Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      categoryIcon,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                  );
                  Widget buildCardContent({Widget? badgeSlot}) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) {
                              final imagePathsRaw = data['imagePaths'];
                              final List<String>? imagePaths = imagePathsRaw is List
                                  ? (imagePathsRaw)
                                      .map((e) => e?.toString() ?? '')
                                      .where((s) => s.isNotEmpty)
                                      .toList()
                                  : null;
                              final String? legacyPath = data['imagePath'] as String?;
                              final List<String> paths = imagePaths != null && imagePaths.isNotEmpty
                                  ? imagePaths
                                  : (legacyPath != null && legacyPath.isNotEmpty
                                      ? [legacyPath]
                                      : const []);
                              return ViewJournalEntryPage(
                                content: content,
                                dateLabel:
                                    dateStr.isEmpty ? 'Journal entry' : dateStr,
                                imagePaths: paths.isEmpty ? null : paths,
                                onDelete: () => _journalRef.doc(doc.id).delete(),
                              );
                            },
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (dateStr.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ?badgeSlot,
                                ],
                              ),
                              if (dateStr.isNotEmpty) const SizedBox(height: 8),
                              Text(
                                preview.isEmpty ? 'No content' : preview,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  void showCategoryMenu() {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SafeArea(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Change category',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              _categorySheetOption(
                                context,
                                'Diary',
                                'diary',
                                doc.id,
                              ),
                              _categorySheetOption(
                                context,
                                'Work',
                                'work',
                                doc.id,
                              ),
                              _categorySheetOption(
                                context,
                                'Life',
                                'life',
                                doc.id,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return KeyedSubtree(
                    key: ValueKey(doc.id),
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: buildCardContent(
                        badgeSlot: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: showCategoryMenu,
                            borderRadius: BorderRadius.circular(8),
                            child: categoryBadge,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _scheduleReadingAloudBannerIfNeeded() {
    if (_bottomTabIndex != 0 ||
        _readingAloudBannerShownThisSession ||
        _readingAloudBannerScheduled) {
      return;
    }
    setState(() => _readingAloudBannerScheduled = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_readingAloudBannerShownThisSession) return;
      setState(() {
        _readingAloudBannerShownThisSession = true;
        _readingAloudBannerVisible = true;
      });
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _readingAloudBannerVisible = false);
      });
    });
  }

  Widget _buildReadingAloudBanner() {
    _scheduleReadingAloudBannerIfNeeded();
    return AnimatedOpacity(
      opacity: _readingAloudBannerVisible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_readingAloudBannerVisible,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Reading aloud makes you more aware of the tasks!!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reorderJournalEntry(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sortedDocs,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    if (newIndex > sortedDocs.length - 1) newIndex = sortedDocs.length - 1;
    if (newIndex < 0) newIndex = 0;
    double orderForDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final data = d.data();
      final order = data['order'];
      if (order is num) return order.toDouble();
      final createdAt = data['createdAt'] as Timestamp?;
      return (createdAt?.millisecondsSinceEpoch ?? 0).toDouble();
    }

    double newOrder;
    if (newIndex == 0) {
      newOrder = orderForDoc(sortedDocs[0]) + 1000;
    } else if (newIndex >= sortedDocs.length - 1) {
      newOrder = orderForDoc(sortedDocs[sortedDocs.length - 1]) - 1000;
    } else {
      newOrder = (orderForDoc(sortedDocs[newIndex - 1]) +
              orderForDoc(sortedDocs[newIndex])) /
          2;
    }

    final doc = sortedDocs[oldIndex];
    try {
      await _journalRef.doc(doc.id).update({'order': newOrder});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: $e')),
        );
      }
    }
  }

  Future<void> _updateJournalCategory(String entryId, String category) async {
    try {
      await _journalRef.doc(entryId).update({'category': category});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update category: $e')),
        );
      }
    }
  }

  Widget _categorySheetOption(
    BuildContext context,
    String label,
    String category,
    String entryId,
  ) {
    final color = _journalCategoryColor(category);
    return ListTile(
      leading: Icon(Icons.label_outline, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
      onTap: () async {
        Navigator.of(context).pop();
        await _updateJournalCategory(entryId, category);
      },
    );
  }

  Color _journalCategoryColor(String category) {
    switch (category) {
      case 'work':
        return const Color(0xFF1976D2);
      case 'life':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF7B1FA2);
    }
  }

  String _formatJournalDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);
    if (entryDay == today) {
      return 'Today';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (entryDay == yesterday) {
      return 'Yesterday';
    }
    return '${_shortMonthName(date.month)} ${date.day}, ${date.year}';
  }

  Future<void> _analyzeSelectedMistakes() async {
    if (_selectedMistakeIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two mistakes to analyze.')),
      );
      return;
    }
    setState(() => _isAnalyzingMistakes = true);
    try {
      final futures = _selectedMistakeIds
          .map((id) => _mistakesRef.doc(id).get())
          .toList(growable: false);
      final snaps = await Future.wait(futures);
      final mistakes = snaps
          .where((s) => s.exists)
          .map((s) {
            final data = s.data() ?? <String, dynamic>{};
            return <String, dynamic>{
              'what': data['what'] ?? '',
              'why': data['why'] ?? '',
              'howToPrevent': data['howToPrevent'] ?? '',
            };
          })
          .toList();
      if (!mounted) return;
      if (mistakes.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load enough mistakes to analyze.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => MistakeAnalysisPage(
            analysesRef: _mistakeAnalysesRef,
            pendingMistakes: mistakes,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingMistakes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 1000;
    final now = DateTime.now();
    final pageTitle = _bottomTabIndex == 0
        ? _displayedMonth
        : (_bottomTabIndex == 1 ? 'Mistakes' : 'Journal');
    final pageSubtitle = _bottomTabIndex == 0
        ? 'Plan with clarity'
        : (_bottomTabIndex == 1
              ? 'Record and learn from mistakes'
              : 'Notes and reflections');

    final showSettingsDrawer = _bottomTabIndex != 1 &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    final appBar = AppBar(
      toolbarHeight: 72,
      flexibleSpace: const LiquidGlassAppBarBackground(),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 18,
        leading: showSettingsDrawer
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pageTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              pageSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF737B8B)),
            ),
          ],
        ),
        actions: [
          if (widget.user.email != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: InkWell(
                  onTap: () => _showLogoutDialog(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE7EAF0)),
                    ),
                    child: Text(
                      widget.user.email!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF616A7C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => TimerPage(
                    focusTasksRef: _focusTasksRef,
                    onAddCompletedTask: ({required String title}) async {
                      await _createTask(
                        title: title,
                        isRecurringDaily: false,
                        initialIsDone: true,
                        dateOverride: DateTime.now(),
                      );
                    },
                  ),
                ),
              );
            },
            tooltip: 'Pomodoro',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE7EAF0)),
            ),
            icon: const Icon(Icons.timer_outlined),
          ),
          const SizedBox(width: 8),
        ],
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _bottomTabIndex == 1
          ? _buildAnalysisHistoryDrawer()
          : showSettingsDrawer
              ? _buildSettingsDrawer()
              : null,
      appBar: appBar,
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + appBar.preferredSize.height,
        ),
        child: Stack(
          children: [
            _bottomTabIndex == 0
                ? _buildTodoTabBody(isDesktopWeb: isDesktopWeb, now: now)
                : (_bottomTabIndex == 1
                      ? _buildMistakesTabBody()
                      : _buildJournalTabBody()),
            if (_bottomTabIndex == 0) _buildReadingAloudBanner(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _bottomTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_rounded),
            label: 'Todo',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Mistakes',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            label: 'Journal',
          ),
        ],
      ),
      floatingActionButton: (!isDesktopWeb)
          ? (_bottomTabIndex == 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        heroTag: 'goal',
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => GoalPlannerPage(
                                initialSelectedDate: _selectedDate,
                                onCreateTask: ({
                                  required DateTime forDate,
                                  required String title,
                                  required List<String> checklistTexts,
                                }) =>
                                    _createTask(
                                  title: title,
                                  isRecurringDaily: false,
                                  checklistItems: checklistTexts,
                                  dateOverride: forDate,
                                ),
                              ),
                            ),
                          );
                        },
                        tooltip: 'Goal planner',
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.flag_circle_outlined),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'add_task',
                        onPressed: _addTask,
                        tooltip: 'Add task',
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  )
                : (_bottomTabIndex == 1
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FloatingActionButton(
                              heroTag: 'mistakes_ai',
                              onPressed: () {
                                if (_isAnalyzingMistakes) return;
                                if (!_mistakeSelectionMode) {
                                  setState(() {
                                    _mistakeSelectionMode = true;
                                    _selectedMistakeIds.clear();
                                  });
                                  return;
                                }
                                if (_selectedMistakeIds.length > 1) {
                                  _analyzeSelectedMistakes();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Select at least two mistakes to send to AI.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              tooltip: _mistakeSelectionMode
                                  ? 'Send to AI'
                                  : 'Analyze mistakes',
                              backgroundColor: const Color(0xFF111111),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _mistakeSelectionMode
                                    ? Icons.auto_awesome
                                    : Icons.psychology_alt_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FloatingActionButton(
                              heroTag: 'add_mistake',
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (context) => AddMistakePage(
                                      mistakesRef: _mistakesRef,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Add mistake',
                              backgroundColor: const Color(0xFF111111),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        )
                      : (_bottomTabIndex == 2
                            ? FloatingActionButton(
                                heroTag: 'journal_add',
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          AddJournalEntryPage(
                                        journalRef: _journalRef,
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'New journal entry',
                                backgroundColor: const Color(0xFF111111),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.add),
                              )
                            : null)))
          : null,
    );
  }
}

class _JournalCategoryFilterChip extends StatelessWidget {
  const _JournalCategoryFilterChip({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

