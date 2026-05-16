import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/auth_gate.dart';
import 'package:simpletodo/app_theme_controller.dart';
import 'package:simpletodo/notification_service.dart';
import 'package:simpletodo/push_notification_service.dart';
import 'package:simpletodo/services/google_sign_in_firebase.dart';
import 'package:hive/hive.dart';
import 'package:simpletodo_data/simpletodo_data.dart' as isar_data;
import 'package:simpletodo_data_core/simpletodo_data_core.dart';
import 'package:simpletodo_data_hive/simpletodo_data_hive.dart' as hive_data;
import 'package:simpletodo_data_objectbox/simpletodo_data_objectbox.dart'
    as ob_data;
import 'package:simpletodo/web_favicon_badge.dart';
import 'package:simpletodo/pages/add_journal_entry_page.dart';
import 'package:simpletodo/pages/add_task_page.dart';
import 'package:simpletodo/pages/mistake_analysis_page.dart';
import 'package:simpletodo/pages/view_journal_entry_page.dart';
import 'package:simpletodo/pages/edit_task_page.dart';
import 'package:simpletodo/health/user_recipe.dart';
import 'package:simpletodo/pages/journal_character_shop_page.dart';
import 'package:simpletodo/pages/journal_personalization_page.dart';
import 'package:simpletodo/pages/notification_settings_page.dart';
import 'package:simpletodo/pages/task_timer_page.dart';
import 'package:simpletodo/utils/task_duration_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpletodo/journal_ai_character_assets.dart';
import 'package:simpletodo/journal_ai_unlock.dart';
import 'package:simpletodo/services/journal_character_unlock.dart';
import 'package:simpletodo/task_completion_rewards.dart';
import 'package:simpletodo/widgets/journal_ai_character_avatar.dart';
import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

typedef _JournalListRow = ({String id, Map<String, dynamic> data});

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

class _TodoHomePageState extends State<TodoHomePage>
    with WidgetsBindingObserver {
  static const bool _useServerPushReminders = true;
  static const String _localDbMode = String.fromEnvironment(
    'localdb',
    defaultValue: 'hive', // isar, hive, or objectbox
  );
  static const Map<String, String> _kCharacterLabels = {
    'default': 'Default assistant',
    'gyaru': '美咲 · gyaru AI',
    'kopitiam_uncle': 'Wong · kopitiam uncle AI',
    'chinese_auntie': 'Yin · auntie AI',
  };
  late final CollectionReference<Map<String, dynamic>> _tasksRef;
  late final CollectionReference<Map<String, dynamic>> _mistakesRef;
  late final CollectionReference<Map<String, dynamic>> _mistakeAnalysesRef;
  late final CollectionReference<Map<String, dynamic>> _journalRef;
  late final CollectionReference<Map<String, dynamic>> _userRecipesRef;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userRecipesSub;
  TaskLocalStore? _taskStore;
  bool _taskStoreReady = false;
  JournalLocalStore? _journalStore;
  bool _journalStoreReady = false;
  Box<String>? _taskOrderBox;
  bool get _useIsar => !kIsWeb && _localDbMode.toLowerCase() == 'isar';
  bool get _useHiveStore => !kIsWeb && _localDbMode.toLowerCase() == 'hive';
  bool get _useObjectBox =>
      !kIsWeb && _localDbMode.toLowerCase() == 'objectbox';
  bool get _useLocalStore => _useIsar || _useHiveStore || _useObjectBox;
  final ScrollController _dateListController = ScrollController();
  final TextEditingController _addTaskTitleController = TextEditingController();
  StreamSubscription<Uri?>? _widgetClickSubscription;
  late DateTime _selectedDate;
  late List<DateTime> _sliderDays;
  late DateTime _sliderDisplayMonth;
  double _lastSliderScrollOffset = 0;
  bool _programmaticSliderScroll = false;
  bool _showJumpToTodayButton = false;
  bool _jumpToTodayOnRight = true;
  bool _taskCreateInProgress = false;
  int _bottomTabIndex = 0;
  /// Prototype: ingredients from Health tab recipes (in-memory until restart).
  final List<String> _shoppingBag = <String>[];
  /// User recipes from Firestore `todo/{uid}/user_recipes`.
  List<UserRecipe> _userRecipes = <UserRecipe>[];

  static const String _kShoppingListTaskTitle = 'Shopping list';
  bool _desktopRecurring = false;
  bool _desktopHasReminder = false;
  TimeOfDay? _desktopReminderTime;
  bool _desktopReminderSuperImportant = false;
  List<TextEditingController> _desktopChecklistControllers = [
    TextEditingController(),
  ];
  List<FocusNode> _desktopChecklistFocusNodes = [FocusNode()];

  /// Serialize checklist toggles per task+day so Firestore updates do not read a stale snapshot.
  final Map<String, Future<void>> _checklistToggleChain =
      <String, Future<void>>{};
  final ScrollController _taskListScrollController = ScrollController();
  bool _isDraggingTask = false;
  bool _mistakeSelectionMode = false;
  final Set<String> _selectedMistakeIds = <String>{};
  bool _isAnalyzingMistakes = false;
  bool get _isAndroidWidgetSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _sliderDays = _buildSliderDays();
    _sliderDisplayMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _dateListController.addListener(_onSliderScroll);
    _tasksRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('tasks')
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
    _userRecipesRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('user_recipes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _userRecipesSub = _userRecipesRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _userRecipes = snapshot.docs
            .map((d) => UserRecipe.fromFirestore(d.id, d.data()))
            .where((r) => r.name.isNotEmpty)
            .toList();
      });
    }, onError: (_, __) {});
    if (_useLocalStore) {
      _journalStore = _useIsar
          ? isar_data.JournalStore(journalRef: _journalRef)
          : _useObjectBox
              ? ob_data.JournalStore(journalRef: _journalRef)
              : hive_data.JournalStore(journalRef: _journalRef);
      unawaited(
        _journalStore!.init().then((_) {
          if (mounted) setState(() => _journalStoreReady = true);
        }),
      );
      _taskStore = _useIsar
          ? isar_data.TaskStore(userId: widget.user.uid, tasksRef: _tasksRef)
          : _useObjectBox
              ? ob_data.TaskStore(userId: widget.user.uid, tasksRef: _tasksRef)
              : hive_data.TaskStore(userId: widget.user.uid, tasksRef: _tasksRef);
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
      _journalStoreReady = true;
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
    _userRecipesSub?.cancel();
    _userRecipesSub = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _desktopChecklistControllers) {
      controller.dispose();
    }
    for (final n in _desktopChecklistFocusNodes) {
      n.dispose();
    }
    _journalStore?.dispose();
    _journalStore = null;
    _taskStore?.dispose();
    _taskStore = null;
    _addTaskTitleController.dispose();
    _dateListController.removeListener(_onSliderScroll);
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

  String _checklistToggleKey(String taskId, DateTime date) {
    return '$taskId|${_dayKey(date)}';
  }

  /// Recurring tasks: show next 7-day payout ladder (coins per day).
  Widget _buildDailyStreakRow(BuildContext context, Map<String, dynamic> data) {
    final nextTier = ((data['recurringStreakRewardDay'] as num?)?.toInt() ?? 1)
        .clamp(1, 7);
    final todayRewardKey = taskRewardDayKey(DateTime.now());
    final rewardedToday =
        (data['lastTaskRewardDayKey'] as String?) == todayRewardKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const blueBorder = Color(0xFF2563EB);
    const blueFill = Color(0xFFEFF6FF);
    const greenBorder = Color(0xFF16A34A);
    const greenFill = Color(0xFFF0FDF4);
    final blueFillDark = const Color(0xFF1A2740);
    final greenFillDark = const Color(0xFF14291F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '7-day streak · next payout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = i + 1;
              final coins = kRecurringStreakCoinsByDay[day - 1];
              final isCompleted = day < nextTier;
              final isToday = day == nextTier && !rewardedToday;
              late final Color bg;
              late final Color borderColor;
              late final double borderWidth;
              late final Color labelColor;
              late final Color coinColor;
              if (isCompleted) {
                bg = isDark ? blueFillDark : blueFill;
                borderColor = blueBorder;
                borderWidth = 1.5;
                labelColor = isDark
                    ? const Color(0xFF93B4FF)
                    : const Color(0xFF1D4ED8);
                coinColor = isDark
                    ? const Color(0xFFBFCEFF)
                    : const Color(0xFF1E40AF);
              } else if (isToday) {
                bg = isDark ? greenFillDark : greenFill;
                borderColor = greenBorder;
                borderWidth = 2;
                labelColor = isDark
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFF15803D);
                coinColor = isDark
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFF166534);
              } else {
                bg = isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100;
                borderColor = isDark
                    ? Theme.of(context).colorScheme.outline
                    : Colors.grey.shade400;
                borderWidth = 1;
                labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
                coinColor = isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.grey.shade700;
              }
              return SizedBox(
                width: 78,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleted) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: labelColor,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        'Day $day',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '+$coins',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                          color: coinColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
          onCreateTask:
              ({
                required String title,
                required bool isRecurringDaily,
                TimeOfDay? reminderTime,
                bool reminderSuperImportant = false,
                List<String>? checklistItems,
              }) => _createTask(
                title: title,
                isRecurringDaily: isRecurringDaily,
                reminderTime: reminderTime,
                reminderSuperImportant: reminderSuperImportant,
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
      reminderSuperImportant:
          _desktopHasReminder && _desktopReminderSuperImportant,
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
      _desktopReminderSuperImportant = false;
      for (final controller in _desktopChecklistControllers) {
        controller.dispose();
      }
      for (final n in _desktopChecklistFocusNodes) {
        n.dispose();
      }
      _desktopChecklistControllers = [TextEditingController()];
      _desktopChecklistFocusNodes = [FocusNode()];
    });
  }

  Future<bool> _ensureReminderPermission() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (enabled) return true;
    final granted = await NotificationService.instance
        .requestNotificationPermission();
    if (granted) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notification permission is required for reminders. Please allow it in settings.',
        ),
      ),
    );
    return false;
  }

  void _focusNextDesktopChecklistField(int index) {
    if (index < _desktopChecklistControllers.length - 1) {
      _desktopChecklistFocusNodes[index + 1].requestFocus();
      return;
    }
    if (_desktopChecklistControllers[index].text.trim().isEmpty) {
      return;
    }
    setState(() {
      _desktopChecklistControllers.add(TextEditingController());
      _desktopChecklistFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _desktopChecklistFocusNodes.last.requestFocus();
      }
    });
  }

  Future<bool> _createTask({
    required String title,
    required bool isRecurringDaily,
    TimeOfDay? reminderTime,
    bool reminderSuperImportant = false,
    List<String>? checklistItems,
    bool initialIsDone = false,
    DateTime? dateOverride,
  }) async {
    if (_taskCreateInProgress) {
      return false;
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    _taskCreateInProgress = true;

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
    if (initialIsDone && !isRecurringDaily) {
      taskData['completedOnDayKey'] = selectedDayKey;
    }
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
      taskData['reminderSuperImportant'] = reminderSuperImportant;
    }

    if (reminderTime != null &&
        (!_useServerPushReminders || reminderSuperImportant)) {
      _scheduleReminder(
        trimmed,
        targetDate,
        reminderTime,
        superImportant: reminderSuperImportant,
      );
    }

    if (reminderTime != null &&
        _useServerPushReminders &&
        !reminderSuperImportant &&
        !kIsWeb &&
        mounted) {
      await PushNotificationService.instance.showRationaleAndRequestPush(
        context,
        title: 'Task reminders',
        message:
            'Allow notifications so this device can receive reminders when your tasks are due.',
      );
    }

    try {
      if (_useLocalStore && _taskStore != null) {
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
    } finally {
      _taskCreateInProgress = false;
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

  _TaskChecklistItem? _checklistItemMatchingText(
    List<_TaskChecklistItem> items,
    String text,
  ) {
    final lower = text.toLowerCase();
    for (final i in items) {
      if (i.text.toLowerCase() == lower) return i;
    }
    return null;
  }

  /// All one-time [Shopping list] tasks for [dayKey], oldest first (canonical is first).
  Future<List<({String id, List<_TaskChecklistItem> items, int createdMs})>>
      _shoppingListMatchesForDay(String dayKey) async {
    final out = <({String id, List<_TaskChecklistItem> items, int createdMs})>[];
    if (_useLocalStore && _taskStore != null) {
      for (final t in _taskStore!.getAllTasks()) {
        if (t.isRecurringDaily) continue;
        if (t.dateKey != dayKey) continue;
        if (t.title.trim() != _kShoppingListTaskTitle) continue;
        final id = _taskStore!.getTaskId(t);
        final items = [
          if (t.checklist != null)
            for (final c in t.checklist!)
              _TaskChecklistItem(text: c.text, isDone: c.isDone),
        ];
        out.add((id: id, items: items, createdMs: t.createdAtMillis ?? 0));
      }
    } else {
      try {
        final snap = await _tasksRef.get();
        for (final doc in snap.docs) {
          final data = doc.data();
          if ((data['isRecurringDaily'] as bool?) == true) continue;
          if ((data['dateKey'] as String?) != dayKey) continue;
          if ((data['title'] as String?)?.trim() != _kShoppingListTaskTitle) {
            continue;
          }
          final c = data['createdAt'];
          final ms = c is Timestamp ? c.millisecondsSinceEpoch : 0;
          out.add((
            id: doc.id,
            items: _taskChecklistFromData(data),
            createdMs: ms,
          ));
        }
      } on FirebaseException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load tasks: ${e.message}')),
          );
        }
        return const [];
      }
    }
    out.sort((a, b) {
      final c = a.createdMs.compareTo(b.createdMs);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return out;
  }

  /// Merges checklist rows from duplicate tasks; same text (case-insensitive) keeps
  /// [isDone] if any row was done.
  List<_TaskChecklistItem> _mergeChecklistItemsDedupe(
    Iterable<_TaskChecklistItem> rows,
  ) {
    final byLower = <String, _TaskChecklistItem>{};
    for (final item in rows) {
      final k = item.text.trim().toLowerCase();
      if (k.isEmpty) continue;
      final prev = byLower[k];
      if (prev == null) {
        byLower[k] = _TaskChecklistItem(text: item.text.trim(), isDone: item.isDone);
      } else {
        byLower[k] = _TaskChecklistItem(
          text: prev.text,
          isDone: prev.isDone || item.isDone,
        );
      }
    }
    return byLower.values.toList();
  }

  Future<void> _deleteTaskById(String id) async {
    if (_useLocalStore && _taskStore != null) {
      await _taskStore!.deleteTask(id);
    } else {
      await _tasksRef.doc(id).delete();
    }
  }

  /// One-time task titled [_kShoppingListTaskTitle] for the selected day: always
  /// a single task — merges duplicates if any, then appends new ingredients.
  Future<void> _appendIngredientsToShoppingListTask(
    List<String> ingredientLines,
  ) async {
    final normalizedNew = _normalizeChecklistTexts(ingredientLines);
    if (normalizedNew.isEmpty) return;

    final dayKey = _dayKey(_selectedDate);
    final matches = await _shoppingListMatchesForDay(dayKey);

    final combinedFromTasks = <_TaskChecklistItem>[];
    for (final m in matches) {
      combinedFromTasks.addAll(m.items);
    }
    final dedupedExisting = _mergeChecklistItemsDedupe(combinedFromTasks);

    final mergedTexts = _normalizeChecklistTexts([
      ...dedupedExisting.map((e) => e.text),
      ...normalizedNew,
    ]);
    final mergedChecklist = mergedTexts.map((text) {
      return _TaskChecklistItem(
        text: text,
        isDone:
            _checklistItemMatchingText(dedupedExisting, text)?.isDone ?? false,
      );
    }).toList();
    final checklistPayload = _checklistToFirestore(mergedChecklist);

    try {
      if (matches.isEmpty) {
        final created = await _createTask(
          title: _kShoppingListTaskTitle,
          isRecurringDaily: false,
          checklistItems: mergedTexts,
        );
        if (!created && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not create Shopping list task.'),
            ),
          );
          return;
        }
      } else {
        final canonicalId = matches.first.id;
        if (_useLocalStore && _taskStore != null) {
          await _taskStore!.updateTask(
            canonicalId,
            <String, dynamic>{'checklist': checklistPayload},
          );
        } else {
          await _tasksRef.doc(canonicalId).update(
            <String, dynamic>{'checklist': checklistPayload},
          );
        }
        for (final m in matches.skip(1)) {
          await _deleteTaskById(m.id);
        }
      }
      _syncTodayWidgetData();
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shopping list task update failed: ${e.message}'),
          ),
        );
      }
    }
  }

  Future<void> _addRecipeFromHealth(
    String recipeTitle,
    List<String> selectedIngredientsForBag,
    List<String> checklistSteps,
  ) async {
    final checklist = checklistSteps.isNotEmpty
        ? checklistSteps
        : ['Cook this recipe'];
    final ok = await _createTask(
      title: '🍳 $recipeTitle',
      isRecurringDaily: false,
      checklistItems: checklist,
    );
    if (!mounted || !ok) return;
    final bagLines = selectedIngredientsForBag
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {
      _shoppingBag.addAll(bagLines);
    });
    if (bagLines.isNotEmpty) {
      await _appendIngredientsToShoppingListTask(bagLines);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bagLines.isEmpty
              ? 'Added “$recipeTitle” · checklist ${checklist.length}'
              : 'Added “$recipeTitle” · checklist ${checklist.length} · bag +${bagLines.length} · merged into “$_kShoppingListTaskTitle”',
        ),
      ),
    );
  }

  void _removeShoppingBagItem(int index) {
    if (index < 0 || index >= _shoppingBag.length) return;
    setState(() => _shoppingBag.removeAt(index));
  }

  Future<void> _persistUserRecipeToFirestore(
    UserRecipe recipe, {
    required bool isNew,
  }) async {
    final payload = <String, dynamic>{
      ...recipe.toFirestoreFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (recipe.thumbUrl == null || recipe.thumbUrl!.trim().isEmpty) {
      payload['thumbUrl'] = FieldValue.delete();
    }
    if (recipe.description == null || recipe.description!.trim().isEmpty) {
      payload['description'] = FieldValue.delete();
    }
    if (isNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await _userRecipesRef.doc(recipe.id).set(payload, SetOptions(merge: true));
  }

  Future<void> _deleteUserRecipeFromFirestore(String id) async {
    try {
      await _userRecipesRef.doc(id).delete();
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete recipe: ${e.message}')),
        );
      }
    }
  }

  void _showShoppingBagSheet() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final maxListHeight = MediaQuery.sizeOf(ctx).height * 0.45;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _shoppingBag.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Your shopping bag is empty.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: maxListHeight,
                        child: ListView.builder(
                          itemCount: _shoppingBag.length,
                          itemBuilder: (context, i) {
                            return ListTile(
                              title: Text(_shoppingBag[i]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _removeShoppingBagItem(i);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() => _shoppingBag.clear());
                        },
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
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
    final bools = _recurringChecklistDoneBoolsForDay(
      data,
      dayKey,
      texts.length,
    );
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
    TimeOfDay time, {
    bool superImportant = false,
  }) async {
    if (kIsWeb) {
      // On web we do not schedule native notifications; instead we surface
      // upcoming reminders via the browser tab icon badge.
      return;
    }
    var scheduledTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final now = DateTime.now();
    final isSameMinuteAsNow =
        scheduledTime.year == now.year &&
        scheduledTime.month == now.month &&
        scheduledTime.day == now.day &&
        scheduledTime.hour == now.hour &&
        scheduledTime.minute == now.minute;
    // UX fix: reminders are minute-based in UI, so selecting the current
    // minute should not fail just because current seconds already advanced.
    if (!scheduledTime.isAfter(now) && isSameMinuteAsNow) {
      scheduledTime = now.add(const Duration(minutes: 1));
    }

    final notifId = await NotificationService.instance.scheduleReminder(
      taskTitle: taskTitle,
      scheduledTime: scheduledTime,
      superImportant: superImportant,
    );

    if (notifId == null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final now = DateTime.now();
      final isPast = !scheduledTime.isAfter(now);
      var permissionBlocked = false;
      if (!isPast) {
        final enabled = await NotificationService.instance
            .areNotificationsEnabled();
        if (!enabled) {
          permissionBlocked = true;
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are blocked. Enable them in Android settings to receive reminders.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
      final message = isPast
          ? 'Reminder time is in the past. Pick a future time.'
          : permissionBlocked
          ? null
          : 'Could not schedule reminder. Check notification permissions.';
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  static const double _dateItemWidth = 68.0;

  List<DateTime> _buildSliderDays() {
    final now = DateTime.now();
    // Start from the first day of the previous month so you can review last
    // month's todos as well.
    final firstDay = DateTime(now.year, now.month - 1, 1);
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

  String _longMonthName(int month) {
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /// Short weekday label (Mon … Sun), aligned with English month abbreviations.
  String _weekdayShortLabel(DateTime date) {
    const w = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[date.weekday - 1];
  }

  int _timestampLikeMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Updates [_sliderDisplayMonth] based on the current slider scroll position.
  ///
  /// Rules:
  /// - When cards move right-to-left (showing later dates), switch to next month
  ///   when that month's last day reaches the left edge.
  /// - When cards move left-to-right (showing earlier dates), switch to previous
  ///   month when day 1 of the current month is no longer visible.
  void _onSliderScroll() {
    if (!_dateListController.hasClients) return;
    if (_sliderDays.isEmpty) return;
    final position = _dateListController.position;
    final offset = position.pixels;
    // Always keep the tracked offset in sync so we correctly detect direction
    // on the next real (user-driven) scroll tick, even if we ignore this one.
    final previousOffset = _lastSliderScrollOffset;
    _lastSliderScrollOffset = offset;
    // Skip programmatic scrolls (initial jump-to, tap-to-scroll animation).
    if (_programmaticSliderScroll) return;
    final viewport = position.viewportDimension;
    final forward = offset > previousOffset;
    final backward = offset < previousOffset;
    if (!forward && !backward) return;

    // Layout constants (must match _buildDateSlider): 14px horizontal padding
    // on the list, 68px item width, 10px trailing gap per item.
    const horizontalPadding = 14.0;
    const itemStride = _dateItemWidth + 10;

    final maxIndex = _sliderDays.length - 1;
    final leftEdge = offset - horizontalPadding;
    final rightEdge = offset + viewport - horizontalPadding;
    final leftMostVisible = (leftEdge / itemStride)
        .floor()
        .clamp(0, maxIndex)
        .toInt();
    final rightMostVisible = ((rightEdge - 0.001) / itemStride)
        .floor()
        .clamp(0, maxIndex)
        .toInt();

    DateTime targetMonth = _sliderDisplayMonth;
    final currentMonthFirstIndex = _sliderDays.indexWhere(
      (d) =>
          d.year == _sliderDisplayMonth.year &&
          d.month == _sliderDisplayMonth.month &&
          d.day == 1,
    );
    final currentMonthLastIndex = _sliderDays.lastIndexWhere(
      (d) =>
          d.year == _sliderDisplayMonth.year &&
          d.month == _sliderDisplayMonth.month,
    );

    if (forward &&
        currentMonthLastIndex >= 0 &&
        leftMostVisible >= currentMonthLastIndex) {
      final currentMonthLastDay = _sliderDays[currentMonthLastIndex];
      final nextMonth = DateTime(
        currentMonthLastDay.year,
        currentMonthLastDay.month + 1,
      );
      targetMonth = DateTime(nextMonth.year, nextMonth.month);
    } else if (backward &&
        currentMonthFirstIndex >= 0 &&
        rightMostVisible < currentMonthFirstIndex) {
      final prevMonth = DateTime(
        _sliderDisplayMonth.year,
        _sliderDisplayMonth.month - 1,
      );
      targetMonth = DateTime(prevMonth.year, prevMonth.month);
    }

    if (targetMonth.year != _sliderDisplayMonth.year ||
        targetMonth.month != _sliderDisplayMonth.month) {
      setState(() => _sliderDisplayMonth = targetMonth);
    }

    _updateJumpToTodayButtonState();
  }

  void _updateJumpToTodayButtonState() {
    if (!_dateListController.hasClients || _sliderDays.isEmpty) return;
    final position = _dateListController.position;
    final offset = position.pixels;
    final viewport = position.viewportDimension;
    const horizontalPadding = 14.0;
    const itemStride = _dateItemWidth + 10;

    final maxIndex = _sliderDays.length - 1;
    final leftEdge = offset - horizontalPadding;
    final rightEdge = offset + viewport - horizontalPadding;
    final leftMostVisible = (leftEdge / itemStride)
        .floor()
        .clamp(0, maxIndex)
        .toInt();
    final rightMostVisible = ((rightEdge - 0.001) / itemStride)
        .floor()
        .clamp(0, maxIndex)
        .toInt();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = _sliderDays.indexWhere((d) => _isSameDay(d, today));
    if (todayIndex < 0) {
      if (_showJumpToTodayButton) {
        setState(() => _showJumpToTodayButton = false);
      }
      return;
    }

    final showButton = todayIndex < leftMostVisible || todayIndex > rightMostVisible;
    final showOnRight = todayIndex > rightMostVisible;
    if (showButton != _showJumpToTodayButton ||
        showOnRight != _jumpToTodayOnRight) {
      setState(() {
        _showJumpToTodayButton = showButton;
        _jumpToTodayOnRight = showOnRight;
      });
    }
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
    _programmaticSliderScroll = true;
    if (animated) {
      _dateListController
          .animateTo(
            offset,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (!mounted) return;
            _lastSliderScrollOffset = _dateListController.hasClients
                ? _dateListController.position.pixels
                : offset;
            _programmaticSliderScroll = false;
            _updateJumpToTodayButtonState();
          });
    } else {
      _dateListController.jumpTo(offset);
      _lastSliderScrollOffset = offset;
      _programmaticSliderScroll = false;
      _updateJumpToTodayButtonState();
    }
  }

  /// True if the document uses per-day completion (daily / recurring-style).
  bool _hasRecurringCompletionFields(Map<String, dynamic> data) {
    final dbd = data['doneByDate'];
    if (dbd is Map && dbd.isNotEmpty) {
      return true;
    }
    final cbd = data['checklistDoneByDate'];
    if (cbd is Map && cbd.isNotEmpty) {
      return true;
    }
    return false;
  }

  void _mergeCompletedOnDayKeyForOneTimeUpdate(
    Map<String, dynamic> updateData,
    bool markDone,
    DateTime completionCalendarDay,
  ) {
    final k = _dayKey(completionCalendarDay);
    if (markDone) {
      updateData['completedOnDayKey'] = k;
    } else {
      updateData['completedOnDayKey'] = FieldValue.delete();
    }
  }

  /// Whether this task should appear for [_selectedDate]. One-time tasks
  /// completed on another day stay hidden when browsing this day; if done today,
  /// [completedOnDayKey] matches and they show at the bottom (strikethrough).
  bool _shouldShowTaskForSelectedDate(Map<String, dynamic> data) {
    final selectedDayKey = _dayKey(_selectedDate);
    String? dateKey = data['dateKey'] as String?;
    final isRecurringDaily =
        ((data['isRecurringDaily'] as bool?) ?? false) ||
        _hasRecurringCompletionFields(data);

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
              : (createdAt is num)
              ? createdAt.toInt()
              : null;
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
      // Carried forward: show incomplete, or done only if completed on this day.
      final done = (data['isDone'] as bool?) ?? false;
      if (!done) {
        return true;
      }
      return (data['completedOnDayKey'] as String?) == selectedDayKey;
    }

    if (dateKey == null) {
      return true;
    }

    return dateKey.compareTo(selectedDayKey) <= 0;
  }

  void _toggleTask(DocumentSnapshot<Map<String, dynamic>> doc, bool value) {
    if (_useLocalStore) {
      unawaited(_toggleTaskById(doc.id, value));
      return;
    }
    unawaited(_toggleTaskFirestoreDoc(doc.reference, value));
  }

  Future<void> _toggleTaskFirestoreDoc(
    DocumentReference<Map<String, dynamic>> docRef,
    bool value, {
    DateTime? completionCalendarDate,
  }) async {
    final cal = completionCalendarDate ?? _selectedDate;
    final calDay = DateTime(cal.year, cal.month, cal.day);
    var shouldHaptic = false;
    var coinsEarned = 0;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          return;
        }
        final data = snap.data() ?? <String, dynamic>{};
        final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
        final wasDone = _isTaskDoneForDate(data, calDay);
        final selectedKey = _dayKey(calDay);

        late final Map<String, dynamic> payload;
        late final bool nowDone;

        if (!isRecurringDaily) {
          final checklist = _taskChecklistFromData(data);
          if (checklist.isEmpty) {
            nowDone = value;
            final u = <String, dynamic>{'isDone': value};
            _mergeCompletedOnDayKeyForOneTimeUpdate(u, value, calDay);
            payload = u;
          } else {
            final updatedChecklist = checklist
                .map(
                  (item) => _TaskChecklistItem(text: item.text, isDone: value),
                )
                .toList();
            nowDone = _isChecklistDone(updatedChecklist);
            final u = <String, dynamic>{
              'checklist': _checklistToFirestore(updatedChecklist),
              'isDone': nowDone,
            };
            _mergeCompletedOnDayKeyForOneTimeUpdate(u, nowDone, calDay);
            payload = u;
          }
        } else {
          final texts = _taskChecklistTextsFromData(data);
          if (texts.isEmpty) {
            nowDone = value;
            payload = <String, dynamic>{
              'doneByDate': <String, dynamic>{selectedKey: value},
            };
          } else {
            nowDone = value;
            final template = texts
                .map((t) => <String, dynamic>{'text': t, 'isDone': false})
                .toList();
            payload = <String, dynamic>{
              'checklist': template,
              'doneByDate': <String, dynamic>{selectedKey: value},
              'checklistDoneByDate': <String, dynamic>{
                selectedKey: List<bool>.filled(texts.length, value),
              },
            };
          }
        }

        final reward = computeTaskCompletionReward(
          data: data,
          selectedDate: calDay,
          wasDoneForDay: wasDone,
          nowDoneForDay: nowDone,
        );
        coinsEarned = reward.coins;
        if (reward.taskPatches.isNotEmpty) {
          payload.addAll(reward.taskPatches);
        }
        tx.update(docRef, flattenFirestoreUpdateData(payload));

        if (reward.coins > 0) {
          final userRef = FirebaseFirestore.instance
              .collection('todo')
              .doc(widget.user.uid);
          tx.set(userRef, <String, dynamic>{
            'taskCoins': FieldValue.increment(reward.coins),
          }, SetOptions(merge: true));
        }
        shouldHaptic = !wasDone && nowDone;
      });
      if (shouldHaptic) {
        _playTaskDoneHaptic();
      }
      if (coinsEarned > 0 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('+$coinsEarned coins')));
      }
      unawaited(_syncTodayWidgetData());
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (e is FirebaseException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.message ?? e.code}')),
        );
      }
    }
  }

  Future<void> _toggleTaskById(String taskId, bool value) async {
    final task = _taskStore!.getTask(taskId);
    if (task == null) return;

    final data = _taskStore!.taskToMap(task);
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
    final checklist = _taskChecklistFromData(data);
    final wasDone = _isTaskDoneForDate(data, _selectedDate);
    try {
      late final Map<String, dynamic> updateData;
      late final bool nowDone;
      if (!isRecurringDaily) {
        if (checklist.isEmpty) {
          nowDone = value;
          updateData = <String, dynamic>{'isDone': value};
        } else {
          final updatedChecklist = checklist
              .map((item) => _TaskChecklistItem(text: item.text, isDone: value))
              .toList();
          nowDone = _isChecklistDone(updatedChecklist);
          updateData = <String, dynamic>{
            'checklist': _checklistToFirestore(updatedChecklist),
            'isDone': nowDone,
          };
        }
      } else {
        final selectedKey = _dayKey(_selectedDate);
        final texts = _taskChecklistTextsFromData(data);
        if (texts.isEmpty) {
          nowDone = value;
          updateData = <String, dynamic>{
            'doneByDate': <String, dynamic>{selectedKey: value},
          };
        } else {
          nowDone = value;
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
      if (!isRecurringDaily) {
        _mergeCompletedOnDayKeyForOneTimeUpdate(
          updateData,
          nowDone,
          _selectedDate,
        );
      }
      final reward = computeTaskCompletionReward(
        data: data,
        selectedDate: _selectedDate,
        wasDoneForDay: wasDone,
        nowDoneForDay: nowDone,
      );
      if (reward.taskPatches.isNotEmpty) {
        updateData.addAll(reward.taskPatches);
      }
      await _taskStore!.updateTask(taskId, updateData);
      if (reward.coins > 0) {
        await FirebaseFirestore.instance
            .collection('todo')
            .doc(widget.user.uid)
            .set(<String, dynamic>{
              'taskCoins': FieldValue.increment(reward.coins),
            }, SetOptions(merge: true));
      }
      if (!wasDone && nowDone) {
        _playTaskDoneHaptic();
      }
      if (reward.coins > 0 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('+${reward.coins} coins')));
      }
      unawaited(_syncTodayWidgetData());
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> _toggleChecklistItem(
    DocumentSnapshot<Map<String, dynamic>> doc,
    int index,
    bool value,
  ) async {
    final key = _checklistToggleKey(doc.id, _selectedDate);
    final prev = _checklistToggleChain[key] ?? Future<void>.value();
    // Do not stall the queue if a prior toggle failed (e.g. offline).
    final next = prev.catchError((_) {}).then((_) async {
      if (_useLocalStore) {
        await _toggleChecklistItemById(doc.id, index, value);
      } else {
        await _toggleChecklistItemFirestore(doc, index, value);
      }
    });
    _checklistToggleChain[key] = next;
    try {
      await next;
    } finally {
      if (_checklistToggleChain[key] == next) {
        _checklistToggleChain.remove(key);
      }
    }
  }

  Future<void> _toggleChecklistItemFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    int index,
    bool value,
  ) async {
    try {
      final fresh = await doc.reference.get();
      if (!fresh.exists) {
        return;
      }
      final data = fresh.data() ?? <String, dynamic>{};
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
        final wasDone = _isTaskDoneForDate(data, _selectedDate);
        final isDone = bools.every((e) => e);
        final template = texts
            .map((t) => <String, dynamic>{'text': t, 'isDone': false})
            .toList();
        final updateData = <String, dynamic>{
          'checklist': template,
          'checklistDoneByDate': <String, dynamic>{dayKey: bools},
          'doneByDate': <String, dynamic>{dayKey: isDone},
        };
        final reward = computeTaskCompletionReward(
          data: data,
          selectedDate: _selectedDate,
          wasDoneForDay: wasDone,
          nowDoneForDay: isDone,
        );
        if (reward.taskPatches.isNotEmpty) {
          updateData.addAll(reward.taskPatches);
        }
        await doc.reference.update(flattenFirestoreUpdateData(updateData));
        if (reward.coins > 0) {
          await FirebaseFirestore.instance
              .collection('todo')
              .doc(widget.user.uid)
              .set(<String, dynamic>{
                'taskCoins': FieldValue.increment(reward.coins),
              }, SetOptions(merge: true));
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('+${reward.coins} coins')));
          }
        }
        if (!wasDone && isDone) {
          _playTaskDoneHaptic();
        }
        await _syncTodayWidgetData();
        return;
      }
      final checklist = _taskChecklistFromData(data);
      if (index < 0 || index >= checklist.length) {
        return;
      }
      final updatedChecklist = List<_TaskChecklistItem>.from(checklist);
      final wasDone = _isTaskDoneForDate(data, _selectedDate);
      updatedChecklist[index] = _TaskChecklistItem(
        text: updatedChecklist[index].text,
        isDone: value,
      );
      final isDone = _isChecklistDone(updatedChecklist);
      final updateData = <String, dynamic>{
        'checklist': _checklistToFirestore(updatedChecklist),
        'isDone': isDone,
      };
      _mergeCompletedOnDayKeyForOneTimeUpdate(
        updateData,
        isDone,
        _selectedDate,
      );
      final reward = computeTaskCompletionReward(
        data: data,
        selectedDate: _selectedDate,
        wasDoneForDay: wasDone,
        nowDoneForDay: isDone,
      );
      if (reward.taskPatches.isNotEmpty) {
        updateData.addAll(reward.taskPatches);
      }
      await doc.reference.update(flattenFirestoreUpdateData(updateData));
      if (reward.coins > 0) {
        await FirebaseFirestore.instance
            .collection('todo')
            .doc(widget.user.uid)
            .set(<String, dynamic>{
              'taskCoins': FieldValue.increment(reward.coins),
            }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('+${reward.coins} coins')));
        }
      }
      if (!wasDone && isDone) {
        _playTaskDoneHaptic();
      }
      await _syncTodayWidgetData();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
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
    final wasDone = _isTaskDoneForDate(data, _selectedDate);
    Map<String, dynamic> updateData;
    late final bool nowDone;
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
      nowDone = bools.every((e) => e);
      final template = texts
          .map((t) => <String, dynamic>{'text': t, 'isDone': false})
          .toList();
      updateData = <String, dynamic>{
        'checklist': template,
        'checklistDoneByDate': <String, dynamic>{dayKey: bools},
        'doneByDate': <String, dynamic>{dayKey: nowDone},
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
      nowDone = _isChecklistDone(updatedChecklist);

      updateData = <String, dynamic>{
        'checklist': _checklistToFirestore(updatedChecklist),
        'isDone': nowDone,
      };
      _mergeCompletedOnDayKeyForOneTimeUpdate(
        updateData,
        nowDone,
        _selectedDate,
      );
    }

    final reward = computeTaskCompletionReward(
      data: data,
      selectedDate: _selectedDate,
      wasDoneForDay: wasDone,
      nowDoneForDay: nowDone,
    );
    if (reward.taskPatches.isNotEmpty) {
      updateData.addAll(reward.taskPatches);
    }

    try {
      await _taskStore!.updateTask(taskId, updateData);
      if (reward.coins > 0) {
        await FirebaseFirestore.instance
            .collection('todo')
            .doc(widget.user.uid)
            .set(<String, dynamic>{
              'taskCoins': FieldValue.increment(reward.coins),
            }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('+${reward.coins} coins')));
        }
      }
      if (!wasDone && nowDone) {
        _playTaskDoneHaptic();
      }
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
              if (!isDone) {
                return true;
              }
              return (data['completedOnDayKey'] as String?) == todayKey;
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
                _timestampLikeMillis(a.data()['createdAt']);
            final bCreated =
                _timestampLikeMillis(b.data()['createdAt']);
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
        final checklist = _taskChecklistFromDataForDate(data, DateTime.now());
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_id',
          widgetTasks[i].id,
        );
        await HomeWidget.saveWidgetData<String>('today_task_${i}_title', title);
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_toggle_done',
          isDone ? '0' : '1',
        );
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_is_done',
          isDone ? '1' : '0',
        );
        final isRecurring = (data['isRecurringDaily'] as bool?) ?? false;
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_is_recurring',
          isRecurring ? '1' : '0',
        );
        await HomeWidget.saveWidgetData<String>(
          'today_task_${i}_checklist_count',
          checklist.length.toString(),
        );
        for (var j = 0; j < checklist.length; j++) {
          await HomeWidget.saveWidgetData<String>(
            'today_task_${i}_checklist_${j}_text',
            checklist[j].text,
          );
          await HomeWidget.saveWidgetData<String>(
            'today_task_${i}_checklist_${j}_is_done',
            checklist[j].isDone ? '1' : '0',
          );
        }
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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await _toggleTaskFirestoreDoc(
          _tasksRef.doc(taskId),
          done,
          completionCalendarDate: today,
        );
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

  Future<void> _showTaskDetailSheetById(String taskId, LocalTask task) async {
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
    final initialChecklist = _taskChecklistFromDataForDate(data, _selectedDate);
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
    final initialReminderSuperImportant =
        (data['reminderSuperImportant'] as bool?) ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var isDeleting = false;
        var displayedChecklist = List<_TaskChecklistItem>.from(
          initialChecklist,
        );

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
                              initialIsRecurringDaily
                                  ? 'Daily streak'
                                  : 'Task detail',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (!context.mounted) return;
                              final editChecklist = displayedChecklist
                                  .map(
                                    (e) => EditTaskChecklistItem(
                                      text: e.text,
                                      isDone: e.isDone,
                                    ),
                                  )
                                  .toList();
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) => EditTaskPage(
                                    taskId: taskId,
                                    dateKey: dateKey,
                                    initialTitle: initialTitle,
                                    initialChecklist: editChecklist.isEmpty
                                        ? [
                                            EditTaskChecklistItem(
                                              text: '',
                                              isDone: false,
                                            ),
                                          ]
                                        : editChecklist,
                                    initialIsRecurringDaily:
                                        initialIsRecurringDaily,
                                    initialHasReminder: initialHasReminder,
                                    initialReminderTime: initialReminderTime,
                                    initialReminderSuperImportant:
                                        initialReminderSuperImportant,
                                    onSave:
                                        ({
                                          required String title,
                                          required List<String> checklistTexts,
                                          required bool isRecurringDaily,
                                          required bool hasReminder,
                                          TimeOfDay? reminderTime,
                                          required bool reminderSuperImportant,
                                        }) async {
                                          final normalizedChecklist =
                                              _normalizeChecklistTexts(
                                                checklistTexts,
                                              );
                                          final isChecklistTask =
                                              normalizedChecklist.isNotEmpty;
                                          final updateData = <String, dynamic>{
                                            'title': title,
                                            'isRecurringDaily':
                                                isRecurringDaily,
                                            'checklist': isChecklistTask
                                                ? normalizedChecklist
                                                      .map(
                                                        (text) =>
                                                            <String, dynamic>{
                                                              'text': text,
                                                              'isDone': false,
                                                            },
                                                      )
                                                      .toList()
                                                : FieldValue.delete(),
                                            'isDone': isChecklistTask
                                                ? false
                                                : (data['isDone'] as bool?) ??
                                                      false,
                                          };
                                          if (isRecurringDaily) {
                                            if (!isChecklistTask) {
                                              updateData['checklistDoneByDate'] =
                                                  FieldValue.delete();
                                            } else {
                                              final oldNormalized =
                                                  _normalizeChecklistTexts(
                                                    _taskChecklistTextsFromData(
                                                      data,
                                                    ),
                                                  );
                                              if (oldNormalized.length !=
                                                      normalizedChecklist
                                                          .length ||
                                                  !listEquals(
                                                    oldNormalized,
                                                    normalizedChecklist,
                                                  )) {
                                                updateData['checklistDoneByDate'] =
                                                    FieldValue.delete();
                                              }
                                            }
                                          }
                                          if (hasReminder &&
                                              reminderTime != null) {
                                            final reminderDate =
                                                _parseDayKey(dateKey) ??
                                                _selectedDate;
                                            var remindAt = DateTime(
                                              reminderDate.year,
                                              reminderDate.month,
                                              reminderDate.day,
                                              reminderTime.hour,
                                              reminderTime.minute,
                                            );
                                            if (isRecurringDaily) {
                                              while (!remindAt.isAfter(
                                                DateTime.now(),
                                              )) {
                                                remindAt = remindAt.add(
                                                  const Duration(days: 1),
                                                );
                                              }
                                            }
                                            updateData['reminderHour'] =
                                                reminderTime.hour;
                                            updateData['reminderMinute'] =
                                                reminderTime.minute;
                                            updateData['remindAt'] =
                                                Timestamp.fromDate(
                                                  remindAt.toUtc(),
                                                );
                                            updateData['reminderPending'] =
                                                true;
                                            updateData['reminderSuperImportant'] =
                                                reminderSuperImportant;
                                          } else {
                                            updateData['reminderHour'] =
                                                FieldValue.delete();
                                            updateData['reminderMinute'] =
                                                FieldValue.delete();
                                            updateData['remindAt'] =
                                                FieldValue.delete();
                                            updateData['reminderPending'] =
                                                false;
                                            updateData['reminderSuperImportant'] =
                                                FieldValue.delete();
                                          }
                                          if (!isRecurringDaily) {
                                            final nd =
                                                updateData['isDone'] as bool?;
                                            if (nd == false) {
                                              updateData['completedOnDayKey'] =
                                                  FieldValue.delete();
                                            }
                                          }
                                          if (hasReminder &&
                                              reminderTime != null &&
                                              (_useServerPushReminders &&
                                                  !reminderSuperImportant) &&
                                              !kIsWeb &&
                                              context.mounted) {
                                            await PushNotificationService
                                                .instance
                                                .showRationaleAndRequestPush(
                                                  context,
                                                  title: 'Task reminders',
                                                  message:
                                                      'Allow notifications so this device can receive reminders when your tasks are due.',
                                                );
                                          }
                                          if (hasReminder &&
                                              reminderTime != null &&
                                              (!_useServerPushReminders ||
                                                  reminderSuperImportant)) {
                                            final reminderDate =
                                                _parseDayKey(dateKey) ??
                                                _selectedDate;
                                            await _scheduleReminder(
                                              title,
                                              reminderDate,
                                              reminderTime,
                                              superImportant:
                                                  reminderSuperImportant,
                                            );
                                          }
                                          if (firestoreDoc != null) {
                                            await firestoreDoc.reference.update(
                                              updateData,
                                            );
                                          } else {
                                            await _taskStore!.updateTask(
                                              taskId,
                                              updateData,
                                            );
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
                      Builder(
                        builder: (sheetContext) {
                          final showTimer = taskTitleSuggestsDuration(
                            initialTitle,
                          );
                          final parsedMin = parseMinutesFromTaskTitle(
                            initialTitle,
                          );
                          final effectiveMinutes = (parsedMin ?? 25).clamp(
                            1,
                            24 * 60,
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  initialTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (showTimer)
                                IconButton(
                                  tooltip: 'Timer',
                                  icon: Icon(
                                    Icons.timer_outlined,
                                    color: Colors.indigo.shade700,
                                  ),
                                  onPressed: () {
                                    Navigator.of(sheetContext).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (context) => TaskTimerPage(
                                          taskTitle: initialTitle,
                                          initialDuration: Duration(
                                            minutes: effectiveMinutes.clamp(
                                              1,
                                              24 * 60,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
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
                          final itemMinutes = parseMinutesFromTaskTitle(
                            item.text,
                          );
                          return CheckboxListTile(
                            value: item.isDone,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(item.text),
                            secondary: itemMinutes == null
                                ? null
                                : IconButton(
                                    tooltip: 'Timer ($itemMinutes min)',
                                    icon: Icon(
                                      Icons.timer_outlined,
                                      size: 20,
                                      color: Colors.indigo.shade700,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (context) => TaskTimerPage(
                                            taskTitle: item.text,
                                            initialDuration: Duration(
                                              minutes: itemMinutes.clamp(
                                                1,
                                                24 * 60,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            onChanged: (value) async {
                              final newValue = value ?? false;
                              if (context.mounted) {
                                setSheetState(() {
                                  displayedChecklist[index] =
                                      _TaskChecklistItem(
                                        text: item.text,
                                        isDone: newValue,
                                      );
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
                      if (initialIsRecurringDaily) ...[
                        const SizedBox(height: 14),
                        _buildDailyStreakRow(context, data),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('Close'),
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

  /// Single task row: no card chrome; optional hairline below (list style).
  Widget _taskListRow({
    required BuildContext context,
    required Widget tile,
    required bool isDone,
    required bool showBottomDivider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: isDone ? scheme.surfaceContainerHigh : Colors.transparent,
          child: tile,
        ),
        if (showBottomDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4A4E58)
                : const Color(0xFFDCE0E8),
          ),
      ],
    );
  }

  Widget _doneTasksSectionDivider() {
    final line = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF4A4E58)
        : const Color(0xFFDCE0E8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
      child: Row(
        children: [
          Expanded(child: Divider(thickness: 2, height: 2, color: line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(thickness: 2, height: 2, color: line)),
        ],
      ),
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
        final docs =
            snapshot.data!.docs
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
                if (aOrderVal != bOrderVal)
                  return aOrderVal.compareTo(bOrderVal);
                final aMs =
                    _timestampLikeMillis(a.data()['createdAt']);
                final bMs =
                    _timestampLikeMillis(b.data()['createdAt']);
                return bMs.compareTo(aMs);
              });

        if (kIsWeb) {
          final now = DateTime.now();
          final hasUpcoming = docs.any((doc) {
            final data = doc.data();
            final reminderHour = data['reminderHour'] as int?;
            final reminderMinute = data['reminderMinute'] as int?;
            final reminderPending = (data['reminderPending'] as bool?) ?? false;
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
          final reordered = List<DocumentSnapshot<Map<String, dynamic>>>.from(
            docs,
          );
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          final leftData = newIndex > 0
              ? (reordered[newIndex - 1].data())
              : null;
          final rightData = newIndex < reordered.length - 1
              ? (reordered[newIndex + 1].data())
              : null;
          final leftOrder =
              (leftData != null ? leftData['order'] as num? : null)?.toDouble();
          final rightOrder =
              (rightData != null ? rightData['order'] as num? : null)
                  ?.toDouble();
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
            if (!_isDraggingTask || !_taskListScrollController.hasClients)
              return;
            final y = e.position.dy;
            final h = MediaQuery.of(context).size.height;
            const zoneHeight = 80.0;
            const scrollStep = 10.0;
            if (y < zoneHeight) {
              final newOffset = (_taskListScrollController.offset - scrollStep)
                  .clamp(
                    0.0,
                    _taskListScrollController.position.maxScrollExtent,
                  );
              _taskListScrollController.jumpTo(newOffset);
            } else if (y > h - zoneHeight) {
              final newOffset = (_taskListScrollController.offset + scrollStep)
                  .clamp(
                    0.0,
                    _taskListScrollController.position.maxScrollExtent,
                  );
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
              final checklist = _taskChecklistFromDataForDate(
                data,
                _selectedDate,
              );
              final doneChecklistCount = checklist
                  .where((item) => item.isDone)
                  .length;
              final isDone = _resolvedTaskDoneForDate(doc, _selectedDate);
              final isRecurringDaily =
                  (data['isRecurringDaily'] as bool?) ?? false;
              final prevDone =
                  index > 0 &&
                  _resolvedTaskDoneForDate(docs[index - 1], _selectedDate);
              final showDoneSectionDivider = isDone && index > 0 && !prevDone;

              final tile = ListTile(
                onTap: () => _showTaskDetailSheet(doc),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                leading: Checkbox(
                  value: isDone,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (value) => _toggleTask(doc, value ?? false),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDoneSectionDivider) _doneTasksSectionDivider(),
                  LongPressDraggable<String>(
                    key: ValueKey(doc.id),
                    data: doc.id,
                    onDragStarted: () => setState(() => _isDraggingTask = true),
                    onDragEnd: (_) => setState(() => _isDraggingTask = false),
                    onDraggableCanceled: (_, __) =>
                        setState(() => _isDraggingTask = false),
                    feedback: Material(
                      elevation: 6,
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 24,
                        child: tile,
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: tile),
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        final oldIndex = docs.indexWhere(
                          (d) => d.id == details.data,
                        );
                        if (oldIndex < 0 || oldIndex == index) return;
                        applyReorder(oldIndex, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final showDropSlot =
                            candidateData.isNotEmpty &&
                            !candidateData.contains(doc.id);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDropSlot)
                              Container(
                                height: 36,
                                margin: const EdgeInsets.only(bottom: 2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'Drop here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                            _taskListRow(
                              context: context,
                              tile: tile,
                              isDone: isDone,
                              showBottomDivider: index < docs.length - 1,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskList() {
    if (!_useLocalStore) {
      return _buildTaskListFirestore();
    }
    if (!_taskStoreReady || _taskStore == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<void>(
      stream: _taskStore!.changes,
      builder: (context, _) {
        final allTasks = _taskStore!.getAllTasks();
        final filtered = allTasks
            .where(
              (t) => _shouldShowTaskForSelectedDate(_taskStore!.taskToMap(t)),
            )
            .toList();
        final dateKey = _dayKey(_selectedDate);
        final orderIds =
            _taskOrderBox
                ?.get(dateKey)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [];
        final tasks = filtered
          ..sort((a, b) {
            final aId = _taskStore!.getTaskId(a);
            final bId = _taskStore!.getTaskId(b);
            final aData = _taskStore!.taskToMap(a);
            final bData = _taskStore!.taskToMap(b);
            final aDone = _resolvedTaskDoneForDateById(
              aId,
              aData,
              _selectedDate,
            );
            final bDone = _resolvedTaskDoneForDateById(
              bId,
              bData,
              _selectedDate,
            );
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
          final reordered = List<LocalTask>.from(tasks);
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          final newOrderIds = reordered
              .map((t) => _taskStore!.getTaskId(t))
              .toList();
          _taskOrderBox?.put(dateKey, newOrderIds.join(','));
          setState(() {});
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (PointerMoveEvent e) {
            if (!_isDraggingTask || !_taskListScrollController.hasClients)
              return;
            final y = e.position.dy;
            final h = MediaQuery.of(context).size.height;
            const zoneHeight = 80.0;
            const scrollStep = 10.0;
            if (y < zoneHeight) {
              final newOffset = (_taskListScrollController.offset - scrollStep)
                  .clamp(
                    0.0,
                    _taskListScrollController.position.maxScrollExtent,
                  );
              _taskListScrollController.jumpTo(newOffset);
            } else if (y > h - zoneHeight) {
              final newOffset = (_taskListScrollController.offset + scrollStep)
                  .clamp(
                    0.0,
                    _taskListScrollController.position.maxScrollExtent,
                  );
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
              final checklist = _taskChecklistFromDataForDate(
                data,
                _selectedDate,
              );
              final doneChecklistCount = checklist
                  .where((item) => item.isDone)
                  .length;
              final isDone = _resolvedTaskDoneForDateById(
                taskId,
                data,
                _selectedDate,
              );
              final isRecurringDaily =
                  (data['isRecurringDaily'] as bool?) ?? false;
              final prevDone =
                  index > 0 &&
                  _resolvedTaskDoneForDateById(
                    _taskStore!.getTaskId(tasks[index - 1]),
                    _taskStore!.taskToMap(tasks[index - 1]),
                    _selectedDate,
                  );
              final showDoneSectionDivider = isDone && index > 0 && !prevDone;

              final tile = ListTile(
                onTap: () => _showTaskDetailSheetById(taskId, task),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                leading: Checkbox(
                  value: isDone,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (value) =>
                      unawaited(_toggleTaskById(taskId, value ?? false)),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDoneSectionDivider) _doneTasksSectionDivider(),
                  LongPressDraggable<String>(
                    key: ValueKey(taskId),
                    data: taskId,
                    onDragStarted: () => setState(() => _isDraggingTask = true),
                    onDragEnd: (_) => setState(() => _isDraggingTask = false),
                    onDraggableCanceled: (_, __) =>
                        setState(() => _isDraggingTask = false),
                    feedback: Material(
                      elevation: 6,
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 24,
                        child: tile,
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: tile),
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        final oldIndex = tasks.indexWhere(
                          (t) => _taskStore!.getTaskId(t) == details.data,
                        );
                        if (oldIndex < 0 || oldIndex == index) return;
                        applyReorder(oldIndex, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final showDropSlot =
                            candidateData.isNotEmpty &&
                            !candidateData.contains(taskId);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDropSlot)
                              Container(
                                height: 36,
                                margin: const EdgeInsets.only(bottom: 2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'Drop here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                            _taskListRow(
                              context: context,
                              tile: tile,
                              isDone: isDone,
                              showBottomDivider: index < tasks.length - 1,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopAddPanel() {
    final scheme = Theme.of(context).colorScheme;
    final desktopPanelSurface = scheme.surfaceContainerHighest;
    final desktopFieldBlend = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: desktopPanelSurface,
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
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createTaskFromDesktopPanel(),
            decoration: InputDecoration(
              hintText: 'Task title',
              filled: true,
              fillColor: desktopPanelSurface,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: desktopFieldBlend),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: desktopFieldBlend),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: desktopFieldBlend, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Checklist',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _desktopChecklistControllers.add(TextEditingController());
                    _desktopChecklistFocusNodes.add(FocusNode());
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
                      focusNode: _desktopChecklistFocusNodes[index],
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () =>
                          _focusNextDesktopChecklistField(index),
                      decoration: InputDecoration(
                        hintText: 'Checklist item ${index + 1}',
                        filled: true,
                        fillColor: desktopPanelSurface,
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: desktopFieldBlend),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: desktopFieldBlend),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: desktopFieldBlend,
                            width: 1.2,
                          ),
                        ),
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
                          _desktopChecklistFocusNodes[index].dispose();
                          _desktopChecklistFocusNodes.removeAt(index);
                          final removed = _desktopChecklistControllers.removeAt(
                            index,
                          );
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
            onChanged: (value) async {
              if (value) {
                final ok = await _ensureReminderPermission();
                if (!ok) return;
              }
              setState(() {
                _desktopHasReminder = value;
                if (value && _desktopReminderTime == null) {
                  _desktopReminderTime = const TimeOfDay(hour: 9, minute: 0);
                }
                if (!value) {
                  _desktopReminderSuperImportant = false;
                }
              });
            },
            title: const Text('Add reminder'),
          ),
          if (_desktopHasReminder) ...[
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
                        initialTime:
                            _desktopReminderTime ??
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _desktopReminderSuperImportant,
              activeThumbColor: const Color(0xFF111111),
              onChanged: (value) async {
                if (value) {
                  final ok = await _ensureReminderPermission();
                  if (!ok) return;
                }
                setState(() {
                  _desktopReminderSuperImportant = value;
                  if (value) {
                    _desktopHasReminder = true;
                    _desktopReminderTime ??= const TimeOfDay(
                      hour: 9,
                      minute: 0,
                    );
                  }
                });
              },
              title: const Text('Super important reminder'),
              subtitle: Text(
                _desktopHasReminder
                    ? 'Android: max importance & alarm-style sound.'
                    : 'Turning this on also enables Add reminder.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _createTaskFromDesktopPanel,
            child: const Text('Create task'),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderMonthHeader(DateTime now) {
    final monthLabel = _longMonthName(_sliderDisplayMonth.month);
    final showYear = _sliderDisplayMonth.year != now.year;
    final label = showYear
        ? '$monthLabel ${_sliderDisplayMonth.year}'
        : monthLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey<String>(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
          final scheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Tooltip(
            message:
                '${_weekdayShortLabel(day)}, ${_shortMonthName(day.month)} ${day.day}',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _sliderDisplayMonth = DateTime(day.year, day.month);
                });
                _scrollDateSliderToSelected(animated: true);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: _dateItemWidth,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF111111)
                        : isToday
                        ? (isDark
                              ? const Color(0xFF1A2740)
                              : const Color(0xFFEFF6FF))
                        : scheme.surface,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF111111)
                          : isToday
                          ? const Color(0xFF4C8AE8)
                          : scheme.outline,
                      width: isToday && !isSelected ? 2.0 : 1.0,
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
                                : isToday
                                ? (isDark
                                      ? const Color(0xFF93B4FF)
                                      : const Color(0xFF6B8DB8))
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        _weekdayShortLabel(day),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isSelected
                              ? Colors.white70
                              : isToday
                              ? (isDark
                                    ? const Color(0xFFBFCEFF)
                                    : const Color(0xFF4A6FA8))
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: isFirstOfMonth ? 15 : 17,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? (isDark
                                    ? const Color(0xFFE8EEF9)
                                    : const Color(0xFF153A62))
                              : scheme.onSurfaceVariant,
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

  Widget _buildDateSliderWithTodayJump(DateTime now) {
    return SizedBox(
      height: 74,
      child: Stack(
        children: [
          Positioned.fill(child: _buildDateSlider(now)),
          if (_showJumpToTodayButton)
            Positioned(
              top: 18,
              left: _jumpToTodayOnRight ? null : 18,
              right: _jumpToTodayOnRight ? 18 : null,
              child: FilledButton.icon(
                onPressed: () {
                  final nowDate = DateTime.now();
                  final today = DateTime(
                    nowDate.year,
                    nowDate.month,
                    nowDate.day,
                  );
                  setState(() {
                    _selectedDate = today;
                    _sliderDisplayMonth = DateTime(today.year, today.month);
                  });
                  _scrollDateSliderToSelected(animated: true);
                },
                icon: Icon(
                  _jumpToTodayOnRight
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  size: 16,
                ),
                label: const SizedBox.shrink(),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodoTabBody({
    required bool isDesktopWeb,
    required DateTime now,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const SizedBox(height: 6),
            _buildSliderMonthHeader(now),
            _buildDateSliderWithTodayJump(now),
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 14),
              Expanded(child: Text('Logging out...')),
            ],
          ),
        ),
      ),
    );
    try {
      await _logoutAndClearCache();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log out. Please try again.')),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _logoutAndClearCache() async {
    await _userRecipesSub?.cancel();
    _userRecipesSub = null;
    _taskStore?.dispose();
    _journalStore?.dispose();
    if (!kIsWeb) {
      if (_useIsar) {
        await isar_data.clearAppIsarOnLogout();
      } else if (_useHiveStore) {
        await hive_data.clearAppHiveOnLogout();
      } else if (_useObjectBox) {
        await ob_data.clearAppObjectBoxOnLogout();
      }
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
    await signOutGoogleSilently();
    AuthGate.markIntentionalSignOut();
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Settings',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListenableBuilder(
              listenable: AppThemeController.instance,
              builder: (context, _) {
                return SwitchListTile(
                  secondary: Icon(
                    AppThemeController.instance.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.dark_mode_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: const Text('Dark mode'),
                  value: AppThemeController.instance.isDark,
                  onChanged: (value) {
                    unawaited(AppThemeController.instance.setDarkMode(value));
                  },
                );
              },
            ),
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
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Journal AI notes'),
              subtitle: const Text('パーソナライズ用のメモ'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const JournalPersonalizationPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('How this app works?'),
              onTap: () {
                Navigator.of(context).pop();
                _showHowThisAppWorksDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About us'),
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: 'Simple Todo',
                  applicationVersion: '1.0.1+3',
                  applicationLegalese: '© ${DateTime.now().year}',
                  children: const [
                    SizedBox(height: 16),
                    Text(
                      'Plan tasks, reflect on mistakes, and keep a journal — '
                      'in one place.',
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.grey.shade700),
              title: const Text('Log out'),
              onTap: () {
                Navigator.of(context).pop();
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHowThisAppWorksDialog(BuildContext anchorContext) async {
    await showDialog<void>(
      context: anchorContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'How this app works?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHowItWorksLine(
                        icon: Icons.toll_rounded,
                        color: const Color(0xFFB45309),
                        text: 'Completing your task will reward you task coin!',
                      ),
                      const SizedBox(height: 10),
                      _buildHowItWorksLine(
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF2563EB),
                        text:
                            'Continuing your daily task may reward you way higher!!',
                      ),
                      const SizedBox(height: 10),
                      _buildHowItWorksLine(
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF7C3AED),
                        text:
                            'You can share your journal with fun AI characters!',
                      ),
                      const SizedBox(height: 10),
                      _buildHowItWorksLine(
                        icon: Icons.lock_open_rounded,
                        color: const Color(0xFF0F766E),
                        text:
                            "Oops, you can't select character? unlock with your ask coin!",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
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

  Widget _buildHowItWorksLine({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3440),
            ),
          ),
        ),
      ],
    );
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: const Color(0xFFFFF3E0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_alt_rounded,
                      size: 18,
                      color: Color(0xFFD35400),
                    ),
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
    if (_useLocalStore) {
      if (!_journalStoreReady || _journalStore == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return StreamBuilder<void>(
        stream: _journalStore!.changes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final entries = _journalStore!.getAllJournalEntries();
          final rows = <_JournalListRow>[
            for (final e in entries) (id: e.id, data: e.toUiMap()),
          ];
          return _buildJournalListFromRows(context, rows);
        },
      );
    }

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
        final rows = <_JournalListRow>[
          for (final d in docs) (id: d.id, data: d.data()),
        ];
        return _buildJournalListFromRows(context, rows);
      },
    );
  }

  Future<void> _showJournalEntryActionSheet({
    required String entryId,
    required Map<String, dynamic> data,
    required bool hasAiFeedback,
    required bool aiRequested,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userSnap = await FirebaseFirestore.instance
        .collection('todo')
        .doc(user.uid)
        .get();
    final userData = userSnap.data() ?? <String, dynamic>{};
    final unlocked = parseUnlockedJournalCharacters(
      userData['unlockedJournalAiCharacters'],
    );
    final selectedRaw = userData['journalAiCharacter'];
    final selectedCharacterId =
        selectedRaw is String && kJournalAiCharacterIds.contains(selectedRaw)
        ? selectedRaw
        : kJournalAiDefaultCharacterId;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final scheme = Theme.of(context).colorScheme;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Share with AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasAiFeedback
                          ? 'Pick a character for another surprise reply—timing stays random.'
                          : (aiRequested
                                ? 'A reply is already queued. Pick a character to request again—timing stays random.'
                                : 'Pick a character. You’ll get a surprise reply when you least expect it.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: kJournalAiCharacterIds.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final id = kJournalAiCharacterIds[index];
                          final label = _kCharacterLabels[id] ?? id;
                          final isUnlocked = isJournalCharacterUnlockedForList(
                            id,
                            unlocked,
                          );
                          final isSelected = selectedCharacterId == id;
                          final cost = unlockCostForJournalCharacter(id);
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                          ? Colors.indigo.shade400
                                          : Colors.indigo.shade200)
                                    : scheme.outline,
                              ),
                              color: isSelected
                                  ? (isDark
                                        ? const Color(0xFF252D40)
                                        : Colors.indigo.shade50)
                                  : scheme.surfaceContainerHighest,
                            ),
                            child: Row(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: JournalAiCharacterAvatar(
                                      characterId: id,
                                      size: 38,
                                      muted: !isUnlocked,
                                      iconColor: isSelected
                                          ? (isDark
                                                ? Colors.indigo.shade200
                                                : Colors.indigo.shade700)
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (!isUnlocked)
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      final r =
                                          await unlockJournalCharacterWithCoins(
                                            uid: user.uid,
                                            characterId: id,
                                          );
                                      if (!mounted) return;
                                      if (r ==
                                          JournalUnlockResult.notEnoughCoins) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Not enough coins.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (r == JournalUnlockResult.error) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not unlock. Try again.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (!unlocked.contains(id)) {
                                        unlocked.add(id);
                                        unlocked.sort();
                                      }
                                      setModalState(() {});
                                    },
                                    child: Text(
                                      cost > 0 ? 'Unlock ($cost)' : 'Unlock',
                                    ),
                                  )
                                else
                                  FilledButton(
                                    onPressed: () async {
                                      Navigator.of(sheetContext).pop();
                                      final updates = <String, dynamic>{
                                        'journalAiFeedbackRequested': true,
                                        'journalAiReplyRequestedAt':
                                            FieldValue.serverTimestamp(),
                                      };
                                      final userRef = FirebaseFirestore.instance
                                          .collection('todo')
                                          .doc(user.uid);
                                      try {
                                        final batch = FirebaseFirestore.instance
                                            .batch();
                                        batch.set(
                                          userRef,
                                          <String, dynamic>{
                                            'journalAiCharacter': id,
                                          },
                                          SetOptions(merge: true),
                                        );
                                        batch.update(
                                          _journalRef.doc(entryId),
                                          updates,
                                        );
                                        await batch.commit();
                                        if (_useLocalStore &&
                                            _journalStore != null) {
                                          await _journalStore!.updateJournal(
                                            entryId,
                                            updates,
                                          );
                                        }
                                        data['journalAiFeedbackRequested'] = true;
                                        if (mounted) setState(() {});
                                        if (!mounted) return;
                                        await _showAiSharedDialog(
                                          characterId: id,
                                          characterLabel:
                                              _kCharacterLabels[id] ?? id,
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to share with AI: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Use this AI'),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAiSharedDialog({
    required String characterId,
    required String characterLabel,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.grey.shade100,
                child: ClipOval(
                  child: JournalAiCharacterAvatar(
                    characterId: characterId,
                    size: 68,
                    iconColor: Colors.indigo.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                characterLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Nice! ${characterLabel.trim()} will drop a surprise reply—watch for a notification.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJournalListFromRows(
    BuildContext context,
    List<_JournalListRow> rows,
  ) {
    double orderForData(Map<String, dynamic> data) {
      final order = data['order'];
      if (order is num) return order.toDouble();
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        return createdAt.millisecondsSinceEpoch.toDouble();
      }
      return 0;
    }

    if (rows.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.06,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No entries yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to write your first journal entry.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<_JournalListRow>.from(rows);
    sorted.sort((a, b) => orderForData(b.data).compareTo(orderForData(a.data)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No entries yet',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final scheme = Theme.of(context).colorScheme;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final row = sorted[index];
                    final data = row.data;
                    final entryId = row.id;
                    final content = data['content'] as String? ?? '';
                    final createdAtRaw = data['createdAt'];
                    final createdAtDate = createdAtRaw is Timestamp
                        ? createdAtRaw.toDate()
                        : (createdAtRaw is num
                              ? DateTime.fromMillisecondsSinceEpoch(
                                  createdAtRaw.toInt(),
                                )
                              : null);
                    final dateStr = createdAtDate != null
                        ? _formatJournalDate(createdAtDate)
                        : '';
                    final preview = content.length > 120
                        ? '${content.substring(0, 120).trim()}...'
                        : content;
                    final aiRaw = data['aiReflection'];
                    final Map<String, dynamic>? aiMap =
                        aiRaw is Map<String, dynamic>
                        ? aiRaw
                        : (aiRaw is Map
                              ? Map<String, dynamic>.from(aiRaw)
                              : null);
                    final aiRequested =
                        (data['journalAiFeedbackRequested'] as bool?) ?? false;
                    final hasAiFeedback =
                        aiMap != null &&
                        ((aiMap['affirmation'] is String &&
                                (aiMap['affirmation'] as String)
                                    .trim()
                                    .isNotEmpty) ||
                            (aiMap['advice'] is String &&
                                (aiMap['advice'] as String).trim().isNotEmpty));
                    final isAiUnread =
                        hasAiFeedback &&
                        aiMap['readAt'] == null &&
                        aiMap['readAtMillis'] == null;
                    final aiCharacterId = () {
                      final raw = aiMap?['character'];
                      if (raw is String) {
                        final t = raw.trim();
                        if (t.isNotEmpty &&
                            kJournalAiCharacterIds.contains(t)) {
                          return t;
                        }
                      }
                      return 'default';
                    }();
                    final Widget? journalAiReplySlot = hasAiFeedback
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAiUnread
                                        ? (isDark
                                              ? const Color(0xFF2A2540)
                                              : const Color(0xFFEDEBFF))
                                        : scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: isAiUnread
                                          ? (isDark
                                                ? Colors.indigo.shade400
                                                : Colors.indigo.shade200)
                                          : scheme.outline,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  child: JournalAiCharacterAvatar(
                                    characterId: aiCharacterId,
                                    size: 36,
                                    iconColor: isDark
                                        ? Colors.indigo.shade200
                                        : Colors.indigo.shade700,
                                  ),
                                ),
                                if (isAiUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.surface,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : null;
                    Widget buildCardContent({Widget? badgeSlot}) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (isAiUnread) {
                              aiMap['readAt'] = Timestamp.now();
                              aiMap['readAtMillis'] =
                                  DateTime.now().millisecondsSinceEpoch;
                              data['aiReflection'] = aiMap;
                              if (mounted) setState(() {});
                              if (_useLocalStore && _journalStore != null) {
                                unawaited(
                                  _journalStore!
                                      .updateJournal(entryId, <String, dynamic>{
                                        'aiReflection': aiMap,
                                        'aiReflection.readAt':
                                            FieldValue.serverTimestamp(),
                                      }),
                                );
                              } else {
                                unawaited(
                                  _journalRef
                                      .doc(entryId)
                                      .update(<String, dynamic>{
                                        'aiReflection.readAt':
                                            FieldValue.serverTimestamp(),
                                      })
                                      .catchError((_) {}),
                                );
                              }
                            }
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) {
                                  final imagePathsRaw = data['imagePaths'];
                                  final List<String>? imagePaths =
                                      imagePathsRaw is List
                                      ? (imagePathsRaw)
                                            .map((e) => e?.toString() ?? '')
                                            .where((s) => s.isNotEmpty)
                                            .toList()
                                      : null;
                                  final String? legacyPath =
                                      data['imagePath'] as String?;
                                  final List<String> paths =
                                      imagePaths != null &&
                                          imagePaths.isNotEmpty
                                      ? imagePaths
                                      : (legacyPath != null &&
                                                legacyPath.isNotEmpty
                                            ? [legacyPath]
                                            : const []);
                                  final aiRaw = data['aiReflection'];
                                  final Map<String, dynamic>? initialAi =
                                      aiRaw is Map<String, dynamic>
                                      ? aiRaw
                                      : (aiRaw is Map
                                            ? Map<String, dynamic>.from(aiRaw)
                                            : null);
                                  return ViewJournalEntryPage(
                                    content: content,
                                    dateLabel: dateStr.isEmpty
                                        ? 'Journal entry'
                                        : dateStr,
                                    imagePaths: paths.isEmpty ? null : paths,
                                    initialAiReflection: initialAi,
                                    onDelete: () async {
                                      if (_useLocalStore &&
                                          _journalStore != null) {
                                        await _journalStore!.deleteJournal(
                                          entryId,
                                        );
                                      } else {
                                        await _journalRef.doc(entryId).delete();
                                      }
                                    },
                                  );
                                },
                              ),
                            );
                          },
                          onLongPress: () {
                            _showJournalEntryActionSheet(
                              entryId: entryId,
                              data: data,
                              hasAiFeedback: hasAiFeedback,
                              aiRequested: aiRequested,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.35 : 0.05,
                                  ),
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
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    if (badgeSlot != null) badgeSlot,
                                  ],
                                ),
                                if (dateStr.isNotEmpty)
                                  const SizedBox(height: 8),
                                Text(
                                  preview.isEmpty ? 'No content' : preview,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: scheme.onSurface,
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
                    return KeyedSubtree(
                      key: ValueKey(entryId),
                      child: buildCardContent(
                        badgeSlot: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (journalAiReplySlot != null) ...[
                              journalAiReplySlot,
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
        const SnackBar(
          content: Text('Select at least two mistakes to analyze.'),
        ),
      );
      return;
    }
    setState(() => _isAnalyzingMistakes = true);
    try {
      final futures = _selectedMistakeIds
          .map((id) => _mistakesRef.doc(id).get())
          .toList(growable: false);
      final snaps = await Future.wait(futures);
      final mistakes = snaps.where((s) => s.exists).map((s) {
        final data = s.data() ?? <String, dynamic>{};
        return <String, dynamic>{
          'what': data['what'] ?? '',
          'why': data['why'] ?? '',
          'howToPrevent': data['howToPrevent'] ?? '',
        };
      }).toList();
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
    final pageTitle = switch (_bottomTabIndex) {
      0 =>
        '${_shortMonthName(_selectedDate.month)} ${_selectedDate.day} · ${_weekdayShortLabel(_selectedDate)}',
      _ => 'Journal',
    };
    final pageSubtitle = switch (_bottomTabIndex) {
      0 => 'Plan with clarity',
      _ => 'Long press to share your journal with AI character',
    };

    final showSettingsDrawer = !kIsWeb;
    final showWebSettingsMenu = kIsWeb;
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
          : showWebSettingsMenu
          ? Builder(
              builder: (menuAnchorContext) {
                return PopupMenuButton<int>(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onSelected: (v) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!menuAnchorContext.mounted) return;
                      switch (v) {
                        case 1:
                          Navigator.of(menuAnchorContext).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const NotificationSettingsPage(),
                            ),
                          );
                        case 2:
                          Navigator.of(menuAnchorContext).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const JournalPersonalizationPage(),
                            ),
                          );
                        case 3:
                          _showHowThisAppWorksDialog(menuAnchorContext);
                        case 4:
                          showAboutDialog(
                            context: menuAnchorContext,
                            applicationName: 'Simple Todo',
                            applicationVersion: '1.0.1+3',
                            applicationLegalese: '© ${DateTime.now().year}',
                            children: const [
                              SizedBox(height: 16),
                              Text(
                                'Plan tasks, reflect on mistakes, and keep '
                                'a journal — in one place.',
                              ),
                            ],
                          );
                        case 5:
                          _showLogoutDialog(menuAnchorContext);
                        case 6:
                          unawaited(
                            AppThemeController.instance.setDarkMode(
                              !AppThemeController.instance.isDark,
                            ),
                          );
                        default:
                          break;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<int>(
                      value: 6,
                      checked: AppThemeController.instance.isDark,
                      child: const Text('Dark mode'),
                    ),
                    const PopupMenuItem<int>(
                      value: 1,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notifications_outlined),
                        title: Text('Set notification'),
                      ),
                    ),
                    const PopupMenuItem<int>(
                      value: 2,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_note_outlined),
                        title: Text('Journal AI notes'),
                        subtitle: Text('パーソナライズ用のメモ'),
                      ),
                    ),
                    const PopupMenuItem<int>(
                      value: 3,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.help_outline_rounded),
                        title: Text('How this app works?'),
                      ),
                    ),
                    const PopupMenuItem<int>(
                      value: 4,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text('About us'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<int>(
                      value: 5,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.logout_rounded,
                          color: Colors.grey.shade700,
                        ),
                        title: const Text('Log out'),
                      ),
                    ),
                  ],
                );
              },
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Center(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('todo')
                  .doc(widget.user.uid)
                  .snapshots(),
              builder: (context, snap) {
                final coins =
                    (snap.data?.data()?['taskCoins'] as num?)?.toInt() ?? 0;
                final scheme = Theme.of(context).colorScheme;
                final coinAccent = Theme.of(context).brightness ==
                        Brightness.dark
                    ? const Color(0xFFFFD66A)
                    : const Color(0xFFE65100);
                return Material(
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              const JournalCharacterShopPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.toll_rounded,
                            size: 20,
                            color: coinAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$coins',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: showSettingsDrawer ? _buildSettingsDrawer() : null,
      appBar: appBar,
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + appBar.preferredSize.height,
        ),
        child: switch (_bottomTabIndex) {
          0 => _buildTodoTabBody(isDesktopWeb: isDesktopWeb, now: now),
          _ => _buildJournalTabBody(),
        },
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
            icon: Icon(Icons.book_outlined),
            label: 'Journal',
          ),
        ],
      ),
      floatingActionButton: isDesktopWeb
          ? switch (_bottomTabIndex) {
              1 => FloatingActionButton(
                  heroTag: 'journal_add_desktop',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => AddJournalEntryPage(
                          journalRef: _journalRef,
                          journalStore: _useLocalStore ? _journalStore : null,
                        ),
                      ),
                    );
                  },
                  tooltip: 'New journal entry',
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFDFE2EA),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onPrimary
                      : const Color(0xFF1C1E24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              _ => null,
            }
          : switch (_bottomTabIndex) {
              0 => FloatingActionButton(
                  heroTag: 'add_task',
                  onPressed: _addTask,
                  tooltip: 'Add task',
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFDFE2EA),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onPrimary
                      : const Color(0xFF1C1E24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              1 => FloatingActionButton(
                  heroTag: 'journal_add',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => AddJournalEntryPage(
                          journalRef: _journalRef,
                          journalStore:
                              _useLocalStore ? _journalStore : null,
                        ),
                      ),
                    );
                  },
                  tooltip: 'New journal entry',
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFDFE2EA),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onPrimary
                      : const Color(0xFF1C1E24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              _ => null,
            },
    );
  }
}
