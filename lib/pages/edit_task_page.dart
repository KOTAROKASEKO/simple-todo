import 'package:flutter/material.dart';

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

  /// Called with form data; implementation updates Firestore/Hive and syncs widget.
  final Future<void> Function({
    required String title,
    required List<String> checklistTexts,
    required bool isRecurringDaily,
    required bool hasReminder,
    TimeOfDay? reminderTime,
  }) onSave;

  final Future<void> Function() onDelete;

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  late final TextEditingController _titleController;
  final List<TextEditingController> _checklistControllers = [];
  late bool _isRecurringDaily;
  late bool _hasReminder;
  late TimeOfDay? _reminderTime;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _checklistSortMode = false;

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
    _isRecurringDaily = widget.initialIsRecurringDaily;
    _hasReminder = widget.initialHasReminder;
    _reminderTime = widget.initialReminderTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
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
        reminderTime: _hasReminder ? (_reminderTime ?? const TimeOfDay(hour: 9, minute: 0)) : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Widget _buildChecklistRow({
    required Key key,
    required int index,
    required TextEditingController controller,
    required bool sortMode,
  }) {
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
                  color: Colors.grey.shade600,
                  size: 24,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Checklist item ${index + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
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
                    _checklistControllers[index].dispose();
                    _checklistControllers.removeAt(index);
                  }
                });
              },
              icon: const Icon(Icons.delete_outline, color: Color(0xFF8A90A0)),
            ),
        ],
      ),
    );
    return KeyedSubtree(key: key, child: row);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit task'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Task title',
                border: OutlineInputBorder(),
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
                    color: Colors.grey.shade700,
                  ),
                  label: Text(
                    _checklistSortMode ? 'Done' : 'Sort order',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _checklistControllers.add(TextEditingController(text: ''));
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add item'),
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
                    _checklistControllers.insert(newIndex, c);
                  });
                },
                itemBuilder: (context, index) {
                  final controller = _checklistControllers[index];
                  return _buildChecklistRow(
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
              activeColor: Colors.black,
              onChanged: (value) {
                setState(() => _isRecurringDaily = value ?? false);
              },
              title: const Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Recurring every day'),
                ],
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasReminder,
              activeThumbColor: const Color(0xFF111111),
              onChanged: (value) {
                setState(() {
                  _hasReminder = value;
                  if (value && _reminderTime == null) {
                    _reminderTime = const TimeOfDay(hour: 9, minute: 0);
                  }
                });
              },
              title: const Text('Reminder'),
            ),
            if (_hasReminder)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: Colors.black54),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                          initialEntryMode: TimePickerEntryMode.input,
                        );
                        if (picked != null) {
                          setState(() => _reminderTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD8D8D8)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _reminderTime?.format(context) ?? '9:00 AM',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    );
  }
}
