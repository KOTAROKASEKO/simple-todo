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

  if (host == 'toggle') {
    final taskId = uri.queryParameters['taskId'];
    final shouldMarkDone = uri.queryParameters['done'] == '1';
    if (taskId == null || taskId.isEmpty) {
      return;
    }
    // Optimistic toggle already applied natively by WidgetToggleReceiver.
    // Only sync to server here.
    await _syncToggleToServer(taskId, shouldMarkDone);
    return;
  }
  if (host != 'refresh') {
    return;
  }

  await _ensureFirebaseInitialized();

  final uid = await HomeWidget.getWidgetData<String>('today_uid');
  if (uid != null && uid.isNotEmpty) {
    await _syncTodayWidgetDataForUid(uid);
  }
}

Future<void> _ensureFirebaseInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _applyOptimisticToggle(
  String taskId,
  bool shouldMarkDone,
) async {
  final taskCountRaw =
      await HomeWidget.getWidgetData<String>('today_task_count', defaultValue: '0');
  final taskCount = int.tryParse(taskCountRaw ?? '0') ?? 0;
  for (var i = 0; i < taskCount; i++) {
    final currentId = await HomeWidget.getWidgetData<String>(
      'today_task_${i}_id',
    );
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
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    await HomeWidget.saveWidgetData<String>('today_updated_at', '$hour:$minute');
    await HomeWidget.updateWidget(androidName: 'TodoTodayWidgetProvider');
    return;
  }
}

Future<bool> _syncToggleToServer(String taskId, bool shouldMarkDone) async {
  try {
    await _ensureFirebaseInitialized();
    final uid = await HomeWidget.getWidgetData<String>('today_uid');
    if (uid == null || uid.isEmpty) {
      return false;
    }

    final taskRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(uid)
        .collection('tasks')
        .doc(taskId);
    final taskSnap = await taskRef.get();
    if (!taskSnap.exists) {
      return false;
    }

    final taskData = taskSnap.data() ?? <String, dynamic>{};
    final isRecurringDaily = (taskData['isRecurringDaily'] as bool?) ?? false;
    if (!isRecurringDaily) {
      await taskRef.update(<String, dynamic>{'isDone': shouldMarkDone});
    } else {
      final todayKey = _dayKey(DateTime.now());
      final texts = _taskChecklistTextsFromData(taskData);
      if (texts.isEmpty) {
        await taskRef.set(<String, dynamic>{
          'doneByDate': <String, dynamic>{todayKey: shouldMarkDone},
        }, SetOptions(merge: true));
      } else {
        final template = texts
            .map((t) => <String, dynamic>{'text': t, 'isDone': false})
            .toList();
        await taskRef.set(<String, dynamic>{
          'checklist': template,
          'doneByDate': <String, dynamic>{todayKey: shouldMarkDone},
          'checklistDoneByDate': <String, dynamic>{
            todayKey: List<bool>.filled(texts.length, shouldMarkDone),
          },
        }, SetOptions(merge: true));
      }
    }

    return true;
  } catch (e) {
    // Keep the optimistic widget state so tap feedback remains immediate even offline.
    debugPrint('Widget toggle sync failed for $taskId: $e');
    return false;
  }
}

String _dayKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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

bool _isTaskDoneForDate(Map<String, dynamic> data, DateTime date) {
  final isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false;
  if (!isRecurringDaily) {
    return (data['isDone'] as bool?) ?? false;
  }

  final key = _dayKey(date);
  final texts = _taskChecklistTextsFromData(data);
  if (texts.isNotEmpty) {
    final bools = _recurringChecklistDoneBoolsForDay(data, key, texts.length);
    return bools.every((e) => e);
  }

  final doneByDateRaw = data['doneByDate'];
  if (doneByDateRaw is Map) {
    final done = doneByDateRaw[key];
    if (done is bool) {
      return done;
    }
  }

  final legacyIsDone = (data['isDone'] as bool?) ?? false;
  final legacyDoneOn = data['lastResetOn'] as String?;
  return legacyIsDone && legacyDoneOn == key;
}

Future<void> _syncTodayWidgetDataForUid(String uid) async {
  final todayKey = _dayKey(DateTime.now());
  final snapshot = await FirebaseFirestore.instance
      .collection('todo')
      .doc(uid)
      .collection('tasks')
      .orderBy('createdAt', descending: true)
      .get();

  final docs =
      snapshot.docs.where((doc) {
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
      }).toList()..sort((a, b) {
        final aDone = _isTaskDoneForDate(a.data(), DateTime.now());
        final bDone = _isTaskDoneForDate(b.data(), DateTime.now());
        if (aDone != bDone) {
          return aDone ? 1 : -1;
        }
        final aCreated =
            (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bCreated =
            (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bCreated.compareTo(aCreated);
      });

  final widgetTasks = docs.take(100).toList();
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');

  await HomeWidget.saveWidgetData<String>('today_uid', uid);
  await HomeWidget.saveWidgetData<String>('today_title', 'Today');
  await HomeWidget.saveWidgetData<String>(
    'today_task_count',
    widgetTasks.length.toString(),
  );
  for (var i = 0; i < widgetTasks.length; i++) {
    final data = widgetTasks[i].data();
    final title = (data['title'] as String?) ?? 'Untitled task';
    final isDone = _isTaskDoneForDate(data, DateTime.now());
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
    final isRecurring = (data['isRecurringDaily'] as bool?) ?? false;
    await HomeWidget.saveWidgetData<String>(
      'today_task_${i}_is_recurring',
      isRecurring ? '1' : '0',
    );
  }
  await HomeWidget.saveWidgetData<String>('today_updated_at', '$hour:$minute');
  await HomeWidget.updateWidget(androidName: 'TodoTodayWidgetProvider');
}
