import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  if (uri == null) {
    return;
  }
  final host = uri.host.toLowerCase();

  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final uid = await HomeWidget.getWidgetData<String>('today_uid');
  if (uid == null || uid.isEmpty) {
    return;
  }

  if (host == 'refresh') {
    await _syncTodayWidgetDataForUid(uid);
    return;
  }
  if (host != 'toggle') {
    return;
  }

  final taskId = uri.queryParameters['taskId'];
  final shouldMarkDone = uri.queryParameters['done'] == '1';
  if (taskId == null || taskId.isEmpty) {
    return;
  }

  try {
    await _applyOptimisticToggle(taskId, shouldMarkDone);
    final tasksRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(uid)
        .collection('tasks');
    await tasksRef.doc(taskId).update(<String, dynamic>{
      'isDone': shouldMarkDone,
      'lastResetOn': _dayKey(DateTime.now()),
    });
    await _syncTodayWidgetDataForUid(uid);
  } catch (_) {
    // Keep callback silent to avoid background crashes.
  }
}

Future<void> _applyOptimisticToggle(String taskId, bool shouldMarkDone) async {
  var changed = false;
  for (var i = 0; i < 4; i++) {
    final currentId = await HomeWidget.getWidgetData<String>('today_task_${i}_id');
    if (currentId != taskId) {
      continue;
    }

    await HomeWidget.saveWidgetData<String>(
      'today_task_${i}_is_done',
      shouldMarkDone ? '1' : '0',
    );
    await HomeWidget.saveWidgetData<String>(
      'today_task_${i}_toggle_done',
      shouldMarkDone ? '0' : '1',
    );
    changed = true;
    break;
  }

  if (!changed) {
    return;
  }

  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  await HomeWidget.saveWidgetData<String>('today_updated_at', '$hour:$minute');
  await HomeWidget.updateWidget(androidName: 'TodoTodayWidgetProvider');
}

String _dayKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Future<void> _syncTodayWidgetDataForUid(String uid) async {
  final todayKey = _dayKey(DateTime.now());
  final snapshot = await FirebaseFirestore.instance
      .collection('todo')
      .doc(uid)
      .collection('tasks')
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

  await HomeWidget.saveWidgetData<String>('today_uid', uid);
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
  await HomeWidget.saveWidgetData<String>('today_updated_at', '$hour:$minute');
  await HomeWidget.updateWidget(androidName: 'TodoTodayWidgetProvider');
}
