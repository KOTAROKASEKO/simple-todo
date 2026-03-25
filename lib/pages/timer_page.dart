import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int _defaultFocusSeconds = 25 * 60;

/// Full-screen Pomodoro / quality timer. Uses [focusTasksRef] for prep tasks
/// and [onAddCompletedTask] to add a "X minutes focused work" task when timer ends.
class TimerPage extends StatefulWidget {
  const TimerPage({
    super.key,
    required this.focusTasksRef,
    required this.onAddCompletedTask,
  });

  final CollectionReference<Map<String, dynamic>> focusTasksRef;
  final Future<void> Function({required String title}) onAddCompletedTask;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final TextEditingController _focusTaskTitleController = TextEditingController();
  Timer? _focusTimer;
  int _focusRemainingSeconds = _defaultFocusSeconds;
  int _focusDurationMinutes = _defaultFocusSeconds ~/ 60;
  bool _isFocusTimerRunning = false;

  @override
  void dispose() {
    _focusTimer?.cancel();
    _focusTaskTitleController.dispose();
    super.dispose();
  }

  String _formatFocusTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleFocusTimer() {
    if (_isFocusTimerRunning) {
      _focusTimer?.cancel();
      setState(() => _isFocusTimerRunning = false);
      return;
    }
    if (_focusRemainingSeconds <= 0) {
      setState(() => _focusRemainingSeconds = _defaultFocusSeconds);
    }
    setState(() {
      _isFocusTimerRunning = true;
      _focusDurationMinutes = _focusRemainingSeconds ~/ 60;
    });
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_focusRemainingSeconds <= 1) {
        timer.cancel();
        final minutes = _focusDurationMinutes;
        setState(() {
          _focusRemainingSeconds = 0;
          _isFocusTimerRunning = false;
        });
        HapticFeedback.mediumImpact();
        widget.onAddCompletedTask(title: '$minutes minutes focused work');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Great work. $minutes-minute quality block done.')),
          );
        }
        return;
      }
      setState(() => _focusRemainingSeconds -= 1);
    });
  }

  void _resetFocusTimer() {
    _focusTimer?.cancel();
    setState(() {
      _isFocusTimerRunning = false;
      _focusRemainingSeconds = _defaultFocusSeconds;
      _focusDurationMinutes = _defaultFocusSeconds ~/ 60;
    });
  }

  Future<void> _addFocusTask() async {
    final title = _focusTaskTitleController.text.trim();
    if (title.isEmpty) return;
    try {
      await widget.focusTasksRef.add(<String, dynamic>{
        'title': title,
        'isDone': false,
        'createdAt': Timestamp.now(),
      });
      _focusTaskTitleController.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to add focus task: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _toggleFocusTask(
      DocumentSnapshot<Map<String, dynamic>> doc, bool value) async {
    try {
      await doc.reference.update(<String, dynamic>{'isDone': value});
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update focus task: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _deleteFocusTask(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete focus task: ${e.message ?? e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7EAF0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Quality Timer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFocusTime(_focusRemainingSeconds),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '25-minute quality block',
                      style: TextStyle(color: Color(0xFF6F7685)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Say it outloud when you check!!',
                      style: TextStyle(
                        color: Color(0xFF6F7685),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _toggleFocusTimer,
                          icon: Icon(
                            _isFocusTimerRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(_isFocusTimerRunning ? 'Pause' : 'Start'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _resetFocusTimer,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Focus prep todo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Keep this list separate for session quality habits.',
                style: TextStyle(color: Color(0xFF6F7685)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _focusTaskTitleController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addFocusTask(),
                      decoration: const InputDecoration(
                        hintText: 'Add a prep task',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addFocusTask,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.focusTasksRef
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Failed to load focus tasks.');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE7EAF0)),
                      ),
                      child: const Text(
                        'No focus tasks yet. Add prep actions for better sessions.',
                        style: TextStyle(color: Color(0xFF6F7685)),
                      ),
                    );
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final title = (data['title'] as String?) ?? 'Untitled';
                      final isDone = (data['isDone'] as bool?) ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE7EAF0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          leading: Checkbox(
                            value: isDone,
                            onChanged: (value) =>
                                _toggleFocusTask(doc, value ?? false),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? const Color(0xFF8A90A0)
                                  : const Color(0xFF17181C),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteFocusTask(doc),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFF8A90A0),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
