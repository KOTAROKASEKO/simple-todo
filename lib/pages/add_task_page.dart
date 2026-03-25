import 'package:flutter/material.dart';

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
    List<String>? checklistItems,
  }) onCreateTask;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _checklistControllers = [
    TextEditingController(),
  ];
  bool _recurring = false;
  bool _hasReminder = false;
  TimeOfDay? _reminderTime;
  bool _isSaving = false;
  bool _checklistSortMode = false;

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _checklistTexts() {
    return _checklistControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                if (controller.text.trim().isEmpty) return;
                setState(() {
                  _checklistControllers.add(TextEditingController());
                });
              },
              decoration: InputDecoration(
                hintText: 'Checklist item ${index + 1}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                    final removed = _checklistControllers.removeAt(index);
                    removed.dispose();
                  }
                });
              },
              icon: Icon(
                Icons.delete_outline,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
    return KeyedSubtree(key: key, child: row);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a task title.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await widget.onCreateTask(
        title: title,
        isRecurringDaily: _recurring,
        reminderTime: _hasReminder ? _reminderTime : null,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.grey.shade700),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New task',
          style: TextStyle(
            color: Colors.grey.shade800,
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Text(
                      'Create',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Task title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                      color: Colors.grey.shade800,
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
                        _checklistControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add item'),
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
                contentPadding: EdgeInsets.zero,
                value: _recurring,
                activeColor: const Color(0xFF111111),
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (value) {
                  setState(() => _recurring = value ?? false);
                },
                title: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Repeat daily',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
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
                title: Text(
                  'Add reminder',
                  style: TextStyle(color: Colors.grey.shade800),
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
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _reminderTime ??
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
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _reminderTime?.format(context) ?? '9:00 AM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
