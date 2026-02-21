import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, required this.user});

  final User user;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late final CollectionReference<Map<String, dynamic>> _tasksRef;
  final ScrollController _dateScrollController = ScrollController();
  final TextEditingController _addTaskTitleController = TextEditingController();
  final TextEditingController _addTaskDescriptionController =
      TextEditingController();
  StreamSubscription<Uri?>? _widgetClickSubscription;
  late DateTime _selectedDate;
  bool _desktopRecurring = false;

  bool get _isAndroidWidgetSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _tasksRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.user.uid)
        .collection('tasks')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _resetRecurringTasksIfNeeded();
    _syncTodayWidgetData();
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
    _dateScrollController.dispose();
    _addTaskTitleController.dispose();
    _addTaskDescriptionController.dispose();
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _resetRecurringTasksIfNeeded() async {
    final today = _dayKey(DateTime.now());
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _tasksRef
          .where('isRecurringDaily', isEqualTo: true)
          .where('isDone', isEqualTo: true)
          .get();
    } on FirebaseException {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    var hasUpdates = false;

    for (final doc in snapshot.docs) {
      final lastResetOn = doc.data()['lastResetOn'] as String?;
      if (lastResetOn != today) {
        hasUpdates = true;
        batch.update(doc.reference, <String, dynamic>{
          'isDone': false,
          'lastResetOn': today,
        });
      }
    }

    if (hasUpdates) {
      await batch.commit();
      await _syncTodayWidgetData();
    }
  }

  Future<void> _addTask() async {
    await _showAddTaskSheet();
  }

  Future<void> _createTaskFromDesktopPanel() async {
    final saved = await _createTask(
      title: _addTaskTitleController.text,
      description: _addTaskDescriptionController.text,
      isRecurringDaily: _desktopRecurring,
    );

    if (!saved) {
      return;
    }

    _addTaskTitleController.clear();
    _addTaskDescriptionController.clear();
    setState(() {
      _desktopRecurring = false;
    });
  }

  Future<bool> _createTask({
    required String title,
    required String description,
    required bool isRecurringDaily,
  }) async {
    final trimmed = title.trim();
    final trimmedDescription = description.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final selectedDayKey = _dayKey(_selectedDate);
    final today = _dayKey(DateTime.now());
    try {
      await _tasksRef.add(<String, dynamic>{
        'title': trimmed,
        'description': trimmedDescription,
        'isDone': false,
        'isRecurringDaily': isRecurringDaily,
        'dateKey': selectedDayKey,
        'lastResetOn': today,
        'createdAt': Timestamp.now(),
      });
      await _syncTodayWidgetData();
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

  Future<void> _showAddTaskSheet() async {
    _addTaskTitleController.clear();
    _addTaskDescriptionController.clear();
    var recurring = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add task for ${_selectedDate.day}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addTaskTitleController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'What did you do?',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addTaskDescriptionController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) async {
                          final saved = await _createTask(
                            title: _addTaskTitleController.text,
                            description: _addTaskDescriptionController.text,
                            isRecurringDaily: recurring,
                          );
                          if (saved && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Add description (optional)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: recurring,
                        activeColor: Colors.black,
                        onChanged: (value) {
                          setSheetState(() {
                            recurring = value ?? false;
                          });
                        },
                        title: const Text('Recurring every day'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () async {
                          final saved = await _createTask(
                            title: _addTaskTitleController.text,
                            description: _addTaskDescriptionController.text,
                            isRecurringDaily: recurring,
                          );
                          if (saved && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Save task'),
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

  List<DateTime> _daysInCurrentMonth() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
    final dayCount = nextMonthFirst.difference(firstDay).inDays;
    return List<DateTime>.generate(
      dayCount,
      (index) => DateTime(now.year, now.month, index + 1),
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

  void _scrollDateSliderToSelected({required bool animated}) {
    if (!_dateScrollController.hasClients) {
      return;
    }

    const itemExtent = 60.0;
    final targetOffset = ((_selectedDate.day - 1) * itemExtent) - 60;
    final maxOffset = _dateScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset).toDouble();

    if (animated) {
      _dateScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _dateScrollController.jumpTo(clampedOffset);
  }

  bool _shouldShowTaskForSelectedDate(Map<String, dynamic> data) {
    final selectedDayKey = _dayKey(_selectedDate);
    final dateKey = data['dateKey'] as String?;
    final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;

    if (!isRecurringDaily) {
      return dateKey == selectedDayKey;
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
    final nowKey = _dayKey(DateTime.now());
    await doc.reference.update(<String, dynamic>{
      'isDone': value,
      'lastResetOn': nowKey,
    });
    await _syncTodayWidgetData();
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

      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        final dateKey = data['dateKey'] as String?;
        final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
        if (!isRecurringDaily) {
          return dateKey == todayKey;
        }
        if (dateKey == null) {
          return true;
        }
        return dateKey.compareTo(todayKey) <= 0;
      }).toList()
        ..sort((a, b) {
          final aDone = (a.data()['isDone'] as bool?) ?? false;
          final bDone = (b.data()['isDone'] as bool?) ?? false;
          if (aDone != bDone) {
            return aDone ? 1 : -1;
          }
          final aCreated =
              (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bCreated =
              (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bCreated.compareTo(aCreated);
        });

      final widgetTasks = docs.take(4).toList();
      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');

      await HomeWidget.saveWidgetData<String>('today_uid', widget.user.uid);
      await HomeWidget.saveWidgetData<String>('today_title', 'Today');
      for (var i = 0; i < 4; i++) {
        if (i < widgetTasks.length) {
          final data = widgetTasks[i].data();
          final title = (data['title'] as String?) ?? 'Untitled task';
          final isDone = (data['isDone'] as bool?) ?? false;
          await HomeWidget.saveWidgetData<String>('today_task_${i}_id', widgetTasks[i].id);
          await HomeWidget.saveWidgetData<String>('today_task_${i}_title', title);
          await HomeWidget.saveWidgetData<String>(
            'today_task_${i}_toggle_done',
            isDone ? '0' : '1',
          );
          await HomeWidget.saveWidgetData<String>(
            'today_task_${i}_is_done',
            isDone ? '1' : '0',
          );
        } else {
          await HomeWidget.saveWidgetData<String>('today_task_${i}_id', '');
          await HomeWidget.saveWidgetData<String>('today_task_${i}_title', '');
          await HomeWidget.saveWidgetData<String>('today_task_${i}_toggle_done', '0');
          await HomeWidget.saveWidgetData<String>('today_task_${i}_is_done', '0');
        }
      }
      await HomeWidget.saveWidgetData<String>(
        'today_updated_at',
        '$hour:$minute',
      );
      await HomeWidget.updateWidget(
        androidName: 'TodoTodayWidgetProvider',
      );
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
        await _tasksRef.doc(taskId).update(<String, dynamic>{
          'isDone': done,
          'lastResetOn': _dayKey(DateTime.now()),
        });
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

  Future<void> _showTaskDetailSheet(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? <String, dynamic>{};
    final initialTitle = (data['title'] as String?) ?? 'Untitled task';
    final initialDescription = (data['description'] as String?) ?? '';
    final initialIsDone = (data['isDone'] as bool?) ?? false;
    final initialIsRecurringDaily =
        (data['isRecurringDaily'] as bool?) ?? false;
    final dateKey = (data['dateKey'] as String?) ?? '-';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var isEditing = false;
        var isSaving = false;
        var isDeleting = false;
        var editedTitle = initialTitle;
        var editedDescription = initialDescription;
        var editedIsRecurringDaily = initialIsRecurringDaily;

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
                              isEditing ? 'Edit task' : 'Task detail',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setSheetState(() {
                                      isEditing = !isEditing;
                                      if (!isEditing) {
                                        editedTitle = initialTitle;
                                        editedDescription = initialDescription;
                                        editedIsRecurringDaily =
                                            initialIsRecurringDaily;
                                      }
                                    });
                                  },
                            child: Text(isEditing ? 'Cancel' : 'Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isEditing) ...[
                        TextFormField(
                          initialValue: editedTitle,
                          onChanged: (value) {
                            editedTitle = value;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Task title',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: editedDescription,
                          onChanged: (value) {
                            editedDescription = value;
                          },
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Description (optional)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: editedIsRecurringDaily,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.black,
                          onChanged: (value) {
                            setSheetState(() {
                              editedIsRecurringDaily = value ?? false;
                            });
                          },
                          title: const Text('Recurring every day'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ] else ...[
                        Text(
                          initialTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          initialDescription.isEmpty
                              ? 'No description'
                              : initialDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Date: $dateKey'),
                      Text(
                        initialIsRecurringDaily
                            ? 'Recurring: Daily'
                            : 'Recurring: No',
                      ),
                      Text(initialIsDone ? 'Status: Done' : 'Status: Not done'),
                      const SizedBox(height: 16),
                      if (isEditing)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final nextTitle = editedTitle.trim();
                                    if (nextTitle.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Title cannot be empty.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = true;
                                    });
                                    try {
                                      await doc.reference
                                          .update(<String, dynamic>{
                                            'title': nextTitle,
                                            'description': editedDescription
                                                .trim(),
                                            'isRecurringDaily':
                                                editedIsRecurringDaily,
                                          });
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
                                              'Failed to update task: ${e.message ?? e.code}',
                                            ),
                                          ),
                                        );
                                      }
                                      setSheetState(() {
                                        isSaving = false;
                                      });
                                    }
                                  },
                            child: Text(
                              isSaving ? 'Saving...' : 'Save changes',
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              await _toggleTask(doc, !initialIsDone);
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
                          onPressed: (isSaving || isDeleting)
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
                                    await doc.reference.delete();
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

  Widget _buildTaskList() {
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
                final aDone = (a.data()['isDone'] as bool?) ?? false;
                final bDone = (b.data()['isDone'] as bool?) ?? false;
                if (aDone != bDone) {
                  return aDone ? 1 : -1;
                }
                final aCreated =
                    (a.data()['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                final bCreated =
                    (b.data()['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                return bCreated.compareTo(aCreated);
              });

        if (docs.isEmpty) {
          return const Center(child: Text('No tasks for this day.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] as String?) ?? 'Untitled task';
            final description = (data['description'] as String?) ?? '';
            final isDone = (data['isDone'] as bool?) ?? false;
            final isRecurringDaily =
                (data['isRecurringDaily'] as bool?) ?? false;
            final rightAccentGradient = isRecurringDaily
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF86EFAC), Color(0xFF16A34A)],
                  );

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3E3E3)),
              ),
              child: Stack(
                children: [
                  ListTile(
                    onTap: () => _showTaskDetailSheet(doc),
                    leading: Checkbox(
                      value: isDone,
                      activeColor: Colors.black,
                      onChanged: (value) => _toggleTask(doc, value ?? false),
                    ),
                    contentPadding: const EdgeInsets.only(left: 8, right: 20),
                    title: Text(
                      title,
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      description.isEmpty
                          ? (isRecurringDaily
                                ? 'Repeats daily'
                                : 'One-time task')
                          : description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      decoration: BoxDecoration(
                        gradient: rightAccentGradient,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopAddPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _addTaskTitleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'What do you do?'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addTaskDescriptionController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createTaskFromDesktopPanel(),
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add description (optional)',
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _desktopRecurring,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.black,
            onChanged: (value) {
              setState(() {
                _desktopRecurring = value ?? false;
              });
            },
            title: const Text('Recurring every day'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _createTaskFromDesktopPanel,
            child: const Text('Save task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthDays = _daysInCurrentMonth();
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text(_monthNameEnglish(DateTime.now().month)),
        actions: [
          if (widget.user.email != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  widget.user.email!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  controller: _dateScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: monthDays.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = monthDays[index];
                    final isSelected = _isSameDay(day, _selectedDate);

                    return Tooltip(
                      message: 'Day ${day.day}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            _selectedDate = day;
                          });
                          _scrollDateSliderToSelected(animated: true);
                        },
                        child: Container(
                          width: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : const Color(0xFFD8D8D8),
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              Expanded(
                child: isDesktopWeb
                    ? Row(
                        children: [
                          const Spacer(),
                          Expanded(flex: 3, child: _buildTaskList()),
                          const SizedBox(width: 20),
                          SizedBox(width: 360, child: _buildDesktopAddPanel()),
                          const SizedBox(width: 20),
                        ],
                      )
                    : _buildTaskList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isDesktopWeb
          ? null
          : FloatingActionButton(
              onPressed: _addTask,
              tooltip: 'Add task',
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }
}
