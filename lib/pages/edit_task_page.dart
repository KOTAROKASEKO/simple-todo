import 'package:flutter/material.dart';
import 'package:simpletodo/notification_service.dart';

/// Simple checklist item for the edit form.
class EditTaskChecklistItem {
  EditTaskChecklistItem({required this.text, this.isDone = false});
  String text;
  bool isDone;
}

/// Page to edit an existing task. Callbacks perform the actual save/delete.
class EditTaskPage extends StatefulWidget {
  const EditTaskPage({
    super.key,
    required this.taskId,
    required this.dateKey,
    required this.initialTitle,
    required this.initialChecklist,
    required this.initialIsRecurringDaily,
    required this.initialHasReminder,
    required this.initialReminderTime,
    this.initialReminderSuperImportant = false,
    required this.onSave,
    required this.onDelete,
  });

  final String taskId;
  final String dateKey;
  final String initialTitle;
  final List<EditTaskChecklistItem> initialChecklist;
  final bool initialIsRecurringDaily;
  final bool initialHasReminder;
  final TimeOfDay? initialReminderTime;
  final bool initialReminderSuperImportant;

  /// Called with form data; implementation updates Firestore/Hive and syncs widget.
  final Future<void> Function({
    required String title,
    required List<String> checklistTexts,
    required bool isRecurringDaily,
    required bool hasReminder,
    TimeOfDay? reminderTime,
    required bool reminderSuperImportant,
  })
  onSave;

  final Future<void> Function() onDelete;

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  late final TextEditingController _titleController;
  final List<TextEditingController> _checklistControllers = [];
  final List<FocusNode> _checklistFocusNodes = [];
  late bool _isRecurringDaily;
  late bool _hasReminder;
  late TimeOfDay? _reminderTime;
  late bool _reminderSuperImportant;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _checklistSortMode = false;

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    final list = widget.initialChecklist;
    if (list.isEmpty) {
      _checklistControllers.add(TextEditingController(text: ''));
    } else {
      for (final e in list) {
        _checklistControllers.add(TextEditingController(text: e.text));
      }
    }
    _checklistFocusNodes.addAll(
      List.generate(_checklistControllers.length, (_) => FocusNode()),
    );
    _isRecurringDaily = widget.initialIsRecurringDaily;
    _hasReminder = widget.initialHasReminder;
    _reminderTime = widget.initialReminderTime;
    _reminderSuperImportant = widget.initialReminderSuperImportant;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    for (final n in _checklistFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _focusNextChecklistField(int index) {
    if (index < _checklistControllers.length - 1) {
      _checklistFocusNodes[index + 1].requestFocus();
      return;
    }
    if (_checklistControllers[index].text.trim().isEmpty) {
      return;
    }
    setState(() {
      _checklistControllers.add(TextEditingController(text: ''));
      _checklistFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checklistFocusNodes.last.requestFocus();
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title cannot be empty.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final checklistTexts = _checklistControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.onSave(
        title: title,
        checklistTexts: checklistTexts,
        isRecurringDaily: _isRecurringDaily,
        hasReminder: _hasReminder,
        reminderTime: _hasReminder
            ? (_reminderTime ?? const TimeOfDay(hour: 9, minute: 0))
            : null,
        reminderSuperImportant: _hasReminder && _reminderSuperImportant,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Widget _buildChecklistRow({
    required BuildContext context,
    required Key key,
    required int index,
    required TextEditingController controller,
    required bool sortMode,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final blendBorder = Theme.of(context).scaffoldBackgroundColor;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (sortMode)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: _checklistFocusNodes[index],
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Checklist item ${index + 1}',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: blendBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: blendBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: blendBorder, width: 1.2),
                ),
              ),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _focusNextChecklistField(index),
            ),
          ),
          if (!sortMode)
            IconButton(
              tooltip: 'Delete item',
              onPressed: () {
                setState(() {
                  if (_checklistControllers.length == 1) {
                    _checklistControllers[0].text = '';
                  } else {
                    _checklistFocusNodes[index].dispose();
                    _checklistFocusNodes.removeAt(index);
                    _checklistControllers[index].dispose();
                    _checklistControllers.removeAt(index);
                  }
                });
              },
              icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
    return KeyedSubtree(key: key, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blendBorder = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Edit task',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: blendBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: blendBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: blendBorder, width: 1.2),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Checklist',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _checklistSortMode = !_checklistSortMode;
                      });
                    },
                    icon: Icon(
                      _checklistSortMode ? Icons.check : Icons.unfold_more,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _checklistSortMode ? 'Done' : 'Sort order',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _checklistControllers.add(
                          TextEditingController(text: ''),
                        );
                        _checklistFocusNodes.add(FocusNode());
                      });
                    },
                    icon: Icon(Icons.add, size: 18, color: scheme.primary),
                    label: Text(
                      'Add item',
                      style: TextStyle(color: scheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_checklistSortMode)
                ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _checklistControllers.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final c = _checklistControllers.removeAt(oldIndex);
                      final fn = _checklistFocusNodes.removeAt(oldIndex);
                      _checklistControllers.insert(newIndex, c);
                      _checklistFocusNodes.insert(newIndex, fn);
                    });
                  },
                  itemBuilder: (context, index) {
                    final controller = _checklistControllers[index];
                    return _buildChecklistRow(
                      context: context,
                      key: ObjectKey(controller),
                      index: index,
                      controller: controller,
                      sortMode: true,
                    );
                  },
                )
              else
                ...List.generate(_checklistControllers.length, (index) {
                  final controller = _checklistControllers[index];
                  return _buildChecklistRow(
                    context: context,
                    key: ObjectKey(controller),
                    index: index,
                    controller: controller,
                    sortMode: false,
                  );
                }),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isRecurringDaily,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() => _isRecurringDaily = value ?? false);
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Recurring every day',
                      style: TextStyle(color: scheme.onSurface),
                    ),
                  ],
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasReminder,
                activeThumbColor: scheme.primary,
                onChanged: (value) async {
                  if (value) {
                    final ok = await _ensureReminderPermission();
                    if (!ok) return;
                  }
                  setState(() {
                    _hasReminder = value;
                    if (value && _reminderTime == null) {
                      _reminderTime = const TimeOfDay(hour: 9, minute: 0);
                    }
                    if (!value) {
                      _reminderSuperImportant = false;
                    }
                  });
                },
                title: Text(
                  'Reminder',
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
              if (_hasReminder)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _reminderTime ??
                                const TimeOfDay(hour: 9, minute: 0),
                            initialEntryMode: TimePickerEntryMode.input,
                          );
                          if (picked != null) {
                            setState(() => _reminderTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            border: Border.all(color: scheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _reminderTime?.format(context) ?? '9:00 AM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminderSuperImportant,
                activeThumbColor: scheme.primary,
                onChanged: (value) async {
                  if (value) {
                    final ok = await _ensureReminderPermission();
                    if (!ok) return;
                  }
                  setState(() {
                    _reminderSuperImportant = value;
                    if (value) {
                      _hasReminder = true;
                      _reminderTime ??= const TimeOfDay(hour: 9, minute: 0);
                    }
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      size: 20,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Super important',
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  _hasReminder
                      ? 'Android: stronger channel (alarm-style).'
                      : 'Turning this on also enables Reminder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save changes'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: (_isSaving || _isDeleting) ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                child: Text(_isDeleting ? 'Deleting...' : 'Delete task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
