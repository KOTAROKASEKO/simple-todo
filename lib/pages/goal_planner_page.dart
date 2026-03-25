import 'package:flutter/material.dart';

/// One checklist item in the goal planner output.
class _PlannerChecklistItem {
  _PlannerChecklistItem({required this.text, required this.checked});
  final String text;
  final bool checked;
}

String _shortMonthName(int month) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}

/// Full-screen goal planner. Calls [onCreateTask] when user adds checked items to Todo.
class GoalPlannerPage extends StatefulWidget {
  const GoalPlannerPage({
    super.key,
    required this.initialSelectedDate,
    required this.onCreateTask,
  });

  final DateTime initialSelectedDate;
  final Future<bool> Function({
    required DateTime forDate,
    required String title,
    required List<String> checklistTexts,
  }) onCreateTask;

  @override
  State<GoalPlannerPage> createState() => _GoalPlannerPageState();
}

class _GoalPlannerPageState extends State<GoalPlannerPage> {
  late DateTime _selectedDate;
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _thinkController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final List<TextEditingController> _outputControllers = <TextEditingController>[
    TextEditingController(),
  ];
  final List<bool> _outputChecked = <bool>[true];
  List<_PlannerChecklistItem> _plannerChecklist = <_PlannerChecklistItem>[];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialSelectedDate;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _thinkController.dispose();
    _outputController.dispose();
    for (final c in _outputControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<_PlannerChecklistItem> _plannerChecklistFromFields() {
    final items = <_PlannerChecklistItem>[];
    final seen = <String>{};
    for (var i = 0; i < _outputControllers.length; i++) {
      final text = _outputControllers[i].text.trim();
      if (text.isEmpty) continue;
      if (!seen.add(text.toLowerCase())) continue;
      final checked = i < _outputChecked.length ? _outputChecked[i] : true;
      items.add(_PlannerChecklistItem(text: text, checked: checked));
    }
    return items;
  }

  void _syncOutputFromFields() {
    _plannerChecklist = _plannerChecklistFromFields();
    final lines = _plannerChecklist
        .map((item) => '- [${item.checked ? 'x' : ' '}] ${item.text}')
        .join('\n');
    _outputController.value = TextEditingValue(
      text: lines,
      selection: TextSelection.collapsed(offset: lines.length),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _importToTodo() async {
    final latest = _plannerChecklistFromFields();
    if (latest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add checklist items in Output first.')),
      );
      return;
    }
    final checklistTexts = latest.where((e) => e.checked).map((e) => e.text).toList();
    if (checklistTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check at least one item to add.')),
      );
      return;
    }
    final goal = _goalController.text.trim();
    final title = goal.isNotEmpty ? goal : 'Goal plan task';
    final created = await widget.onCreateTask(
      forDate: _selectedDate,
      title: title,
      checklistTexts: checklistTexts,
    );
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added task(s) to your todo list.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateText =
        '${_shortMonthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal planner'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final viewInsets = MediaQuery.of(context).viewInsets.bottom;
          final isCompact = width < 600;
          final horizontalPadding = isCompact ? 12.0 : 18.0;
          final verticalPadding = isCompact ? 10.0 : 14.0;
          final sectionSpacing = isCompact ? 10.0 : 12.0;
          final maxContentWidth = isCompact ? width : 800.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              24 + viewInsets,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE7EAF0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 18,
                            color: Color(0xFF5F6778),
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          Expanded(
                            child: Text(
                              'Tasks will be added to $selectedDateText',
                              style: TextStyle(
                                color: const Color(0xFF2F3441),
                                fontWeight: FontWeight.w500,
                                fontSize: isCompact ? 14 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickDate,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    TextField(
                      controller: _goalController,
                      decoration: const InputDecoration(
                        labelText: 'Goal',
                        hintText: 'What outcome do you want?',
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    TextField(
                      controller: _thinkController,
                      minLines: isCompact ? 2 : 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Think here',
                        hintText: 'Write your reasoning or constraints.',
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    const Text(
                      'Output (Checklist)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B3140),
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    ..._outputControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      final checked = index < _outputChecked.length
                          ? _outputChecked[index]
                          : true;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Checkbox(
                                value: checked,
                                onChanged: (value) {
                                  setState(() {
                                    if (index >= _outputChecked.length) {
                                      _outputChecked.add(value ?? true);
                                    } else {
                                      _outputChecked[index] = value ?? true;
                                    }
                                    _syncOutputFromFields();
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(_syncOutputFromFields),
                                onSubmitted: (_) {
                                  if (controller.text.trim().isEmpty) return;
                                  setState(() {
                                    _outputControllers.add(TextEditingController());
                                    _outputChecked.add(true);
                                    _syncOutputFromFields();
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
                                  if (_outputControllers.length == 1) {
                                    _outputControllers.first.clear();
                                    _outputChecked[0] = true;
                                  } else {
                                    final removed = _outputControllers.removeAt(index);
                                    removed.dispose();
                                    _outputChecked.removeAt(index);
                                  }
                                  _syncOutputFromFields();
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _outputControllers.add(TextEditingController());
                            _outputChecked.add(true);
                            _syncOutputFromFields();
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add checklist item'),
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    OutlinedButton.icon(
                      onPressed: _importToTodo,
                      icon: const Icon(Icons.playlist_add_check_circle_outlined),
                      label: const Text('Add checked tasks to Todo'),
                    ),
                    if (_outputController.text.trim().isNotEmpty) ...[
                      SizedBox(height: isCompact ? 12 : 14),
                      const Text(
                        'Checklist Output Text',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B3140),
                        ),
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                      SelectableText(
                        _outputController.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF505766),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
