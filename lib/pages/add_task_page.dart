import 'package:flutter/material.dart';
import 'package:simpletodo/notification_service.dart';

/// Full-screen page to add a new task. Calls [onCreateTask] on save.
class AddTaskPage extends StatefulWidget {
  const AddTaskPage({
    super.key,
    required this.dateLabel,
    required this.onCreateTask,
  });

  /// e.g. "Mar 22"
  final String dateLabel;
  final Future<bool> Function({
    required String title,
    required bool isRecurringDaily,
    TimeOfDay? reminderTime,
    bool reminderSuperImportant,
    List<String>? checklistItems,
  })
  onCreateTask;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _checklistControllers = [
    TextEditingController(),
  ];
  final List<FocusNode> _checklistFocusNodes = [FocusNode()];
  bool _recurring = false;
  bool _hasReminder = false;
  TimeOfDay? _reminderTime;
  bool _reminderSuperImportant = false;
  bool _isSaving = false;
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
      _checklistControllers.add(TextEditingController());
      _checklistFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checklistFocusNodes.last.requestFocus();
      }
    });
  }

  List<String> _checklistTexts() {
    return _checklistControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
              textInputAction: TextInputAction.next,
              style: TextStyle(color: scheme.onSurface),
              onEditingComplete: () => _focusNextChecklistField(index),
              decoration: InputDecoration(
                hintText: 'Checklist item ${index + 1}',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
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
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          if (!sortMode)
            IconButton(
              tooltip: 'Delete',
              onPressed: () {
                setState(() {
                  if (_checklistControllers.length == 1) {
                    _checklistControllers.first.clear();
                  } else {
                    _checklistFocusNodes[index].dispose();
                    _checklistFocusNodes.removeAt(index);
                    final removed = _checklistControllers.removeAt(index);
                    removed.dispose();
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a task title.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await widget.onCreateTask(
        title: title,
        isRecurringDaily: _recurring,
        reminderTime: _hasReminder ? _reminderTime : null,
        reminderSuperImportant: _hasReminder && _reminderSuperImportant,
        checklistItems: _checklistTexts().isNotEmpty ? _checklistTexts() : null,
      );
      if (!mounted) return;
      if (saved) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New task',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : Text(
                      'Create',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'For ${widget.dateLabel}',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
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
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Checklist',
                    style: TextStyle(
                      fontSize: 16,
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
                        _checklistControllers.add(TextEditingController());
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
                contentPadding: EdgeInsets.zero,
                value: _recurring,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (value) {
                  setState(() => _recurring = value ?? false);
                },
                title: Row(
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Repeat daily',
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
                  'Add reminder',
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
              if (_hasReminder)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 19,
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _reminderTime?.format(context) ?? '9:00 AM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
                      ? 'Android: max notification importance, alarm-style sound & vibration.'
                      : 'Turning this on also enables Add reminder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
