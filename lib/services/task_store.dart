import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:simpletodo/models/task_model.dart';

const String _tasksBoxName = 'tasks';

bool _isFieldValueDelete(Object? v) =>
    v.toString().contains('FieldValue');

/// Converts [updateData] for [DocumentReference.update].
///
/// Firestore [set] with merge incorrectly merges each element of an array of
/// maps (e.g. checklist), so updates must use [update] for full field replace.
///
/// [doneByDate] and [checklistDoneByDate] are flattened to dotted paths so one
/// day's value merges into the existing map instead of replacing the whole map.
Map<String, dynamic> flattenFirestoreUpdateData(
  Map<String, dynamic> updateData,
) {
  final out = <String, dynamic>{};
  for (final e in updateData.entries) {
    final k = e.key;
    final v = e.value;
    if (k == 'doneByDate') {
      if (_isFieldValueDelete(v)) {
        out['doneByDate'] = FieldValue.delete();
      } else if (v is Map) {
        for (final de in v.entries) {
          out['doneByDate.${de.key}'] = de.value;
        }
      } else {
        out[k] = v;
      }
    } else if (k == 'checklistDoneByDate') {
      if (_isFieldValueDelete(v)) {
        out['checklistDoneByDate'] = FieldValue.delete();
      } else if (v is Map) {
        for (final de in v.entries) {
          out['checklistDoneByDate.${de.key}'] = de.value;
        }
      } else {
        out[k] = v;
      }
    } else {
      out[k] = v;
    }
  }
  return out;
}

/// Manages task storage: Hive (local) with synchronous Firestore backup on add.
class TaskStore {
  TaskStore({
    required this.userId,
    required this.tasksRef,
  });

  final String userId;
  final CollectionReference<Map<String, dynamic>> tasksRef;

  Box<HiveTask>? _box;
  bool _initialSyncDone = false;

  Box<HiveTask> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('TaskStore not initialized. Call init() first.');
    }
    return b;
  }

  ValueListenable<Box<HiveTask>> get listenable => box.listenable();

  /// Initialize Hive and sync from Firestore.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    _box = await Hive.openBox<HiveTask>(_tasksBoxName);

    if (!_initialSyncDone) {
      await _syncFromFirestore();
      _initialSyncDone = true;
    }
  }

  /// Sync all tasks from Firestore into Hive (initial load).
  Future<void> _syncFromFirestore() async {
    try {
      final snapshot = await tasksRef.orderBy('createdAt', descending: true).get();
      await _box!.clear();
      for (final doc in snapshot.docs) {
        final task = _taskFromFirestoreData(doc.id, doc.data());
        task.firestoreId = doc.id;
        await _box!.put(doc.id, task);
      }
    } catch (_) {
      // Keep existing Hive data if Firestore sync fails (e.g. offline)
    }
  }

  /// Add task: save to Hive first (instant), then backup to Firestore synchronously.
  Future<String?> addTask(Map<String, dynamic> taskData) async {
    final createdAt = (taskData['createdAt'] as Timestamp?) ?? Timestamp.now();
    final task = _taskFromFirestoreData('', taskData)
      ..firestoreId = null
      ..createdAtMillis = createdAt.millisecondsSinceEpoch;

    // Store in Hive immediately (instant local display)
    final tempKey = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(tempKey, task);

    // Backup to Firestore synchronously (await before returning)
    try {
      final docRef = await tasksRef.add(taskData);
      task.firestoreId = docRef.id;
      await box.delete(tempKey);
      await box.put(docRef.id, task);
      return docRef.id;
    } catch (e) {
      await box.delete(tempKey);
      rethrow;
    }
  }

  /// Get all tasks sorted by createdAt descending.
  List<HiveTask> getAllTasks() {
    final tasks = box.values.toList();
    tasks.sort((a, b) {
      final aMs = a.createdAtMillis ?? 0;
      final bMs = b.createdAtMillis ?? 0;
      return bMs.compareTo(aMs);
    });
    return tasks;
  }

  /// Get task id (Firestore doc id or Hive key) for a task.
  String getTaskId(HiveTask task) {
    return task.firestoreId ?? task.key?.toString() ?? '';
  }

  /// Get task by id (Firestore doc id or Hive key).
  HiveTask? getTask(String id) {
    return box.get(id);
  }

  /// Update task in Hive and Firestore.
  Future<void> updateTask(
    String id,
    Map<String, dynamic> updateData,
  ) async {
    final task = box.get(id);
    if (task == null) return;

    _applyUpdateToTask(task, updateData);
    await box.put(id, task);

    final firestoreId = task.firestoreId ?? id;
    try {
      await tasksRef
          .doc(firestoreId)
          .update(flattenFirestoreUpdateData(updateData));
    } catch (e) {
      rethrow;
    }
  }

  /// Delete task from Hive and Firestore.
  Future<void> deleteTask(String id) async {
    final task = box.get(id);
    if (task == null) return;

    final firestoreId = task.firestoreId ?? id;
    await box.delete(id);

    try {
      await tasksRef.doc(firestoreId).delete();
    } catch (_) {
      // Ignore - local delete already done
    }
  }

  /// Convert Firestore data to HiveTask.
  HiveTask _taskFromFirestoreData(String firestoreId, Map<String, dynamic> data) {
    final rawChecklist = data['checklist'];
    List<HiveChecklistItem>? checklist;
    if (rawChecklist is List) {
      checklist = rawChecklist.map((e) {
        if (e is Map) {
          return HiveChecklistItem(
            text: (e['text'] as String?) ?? '',
            isDone: (e['isDone'] as bool?) ?? false,
          );
        }
        return HiveChecklistItem(text: '', isDone: false);
      }).toList();
    }

    Map<String, bool>? doneByDate;
    final rawDoneByDate = data['doneByDate'];
    if (rawDoneByDate is Map) {
      doneByDate = rawDoneByDate.map((k, v) => MapEntry(k.toString(), v == true));
    }

    Map<String, List<bool>>? checklistDoneByDate;
    final rawChecklistDoneByDate = data['checklistDoneByDate'];
    if (rawChecklistDoneByDate is Map) {
      checklistDoneByDate = {};
      for (final e in rawChecklistDoneByDate.entries) {
        final v = e.value;
        if (v is List) {
          checklistDoneByDate[e.key.toString()] =
              v.map((x) => x == true).toList();
        }
      }
    }

    int? remindAtMillis;
    final remindAt = data['remindAt'];
    if (remindAt is Timestamp) {
      remindAtMillis = remindAt.millisecondsSinceEpoch;
    }

    final createdAt = data['createdAt'];
    int? createdAtMillis;
    if (createdAt is Timestamp) {
      createdAtMillis = createdAt.millisecondsSinceEpoch;
    }

    return HiveTask(
      firestoreId: firestoreId.isEmpty ? null : firestoreId,
      title: (data['title'] as String?) ?? 'Untitled',
      isDone: (data['isDone'] as bool?) ?? false,
      isRecurringDaily: (data['isRecurringDaily'] as bool?) ?? false,
      dateKey: data['dateKey'] as String?,
      lastResetOn: data['lastResetOn'] as String?,
      createdAtMillis: createdAtMillis,
      checklist: checklist,
      reminderHour: data['reminderHour'] as int?,
      reminderMinute: data['reminderMinute'] as int?,
      remindAtMillis: remindAtMillis,
      reminderPending: (data['reminderPending'] as bool?) ?? false,
      doneByDate: doneByDate,
      checklistDoneByDate: checklistDoneByDate,
    );
  }

  void _applyUpdateToTask(HiveTask task, Map<String, dynamic> updateData) {

    if (updateData.containsKey('title')) {
      final v = updateData['title'];
      if (!_isFieldValueDelete(v)) task.title = v as String;
    }
    if (updateData.containsKey('isDone')) {
      final v = updateData['isDone'];
      if (!_isFieldValueDelete(v)) task.isDone = v as bool;
    }
    if (updateData.containsKey('isRecurringDaily')) {
      final v = updateData['isRecurringDaily'];
      if (!_isFieldValueDelete(v)) task.isRecurringDaily = v as bool;
    }
    if (updateData.containsKey('checklist')) {
      final raw = updateData['checklist'];
      if (_isFieldValueDelete(raw)) {
        task.checklist = null;
      } else if (raw is List) {
        task.checklist = raw.map((e) {
          if (e is Map) {
            return HiveChecklistItem(
              text: (e['text'] as String?) ?? '',
              isDone: (e['isDone'] as bool?) ?? false,
            );
          }
          return HiveChecklistItem(text: '', isDone: false);
        }).toList();
      }
    }
    if (updateData.containsKey('doneByDate')) {
      final raw = updateData['doneByDate'];
      if (_isFieldValueDelete(raw)) {
        task.doneByDate = null;
      } else if (raw is Map) {
        final merged = Map<String, bool>.from(task.doneByDate ?? {});
        merged.addAll(
          raw.map((k, v) => MapEntry(k.toString(), v == true)),
        );
        task.doneByDate = merged;
      }
    }
    if (updateData.containsKey('checklistDoneByDate')) {
      final raw = updateData['checklistDoneByDate'];
      if (_isFieldValueDelete(raw)) {
        task.checklistDoneByDate = null;
      } else if (raw is Map) {
        task.checklistDoneByDate ??= {};
        for (final e in raw.entries) {
          final v = e.value;
          if (v is List) {
            task.checklistDoneByDate![e.key.toString()] =
                v.map((x) => x == true).toList();
          }
        }
      }
    }
    if (updateData.containsKey('reminderHour')) {
      final v = updateData['reminderHour'];
      task.reminderHour = _isFieldValueDelete(v) ? null : v as int?;
    }
    if (updateData.containsKey('reminderMinute')) {
      final v = updateData['reminderMinute'];
      task.reminderMinute = _isFieldValueDelete(v) ? null : v as int?;
    }
    if (updateData.containsKey('remindAt')) {
      final v = updateData['remindAt'];
      task.remindAtMillis = _isFieldValueDelete(v)
          ? null
          : (v is Timestamp ? v.millisecondsSinceEpoch : null);
    }
    if (updateData.containsKey('reminderPending')) {
      final v = updateData['reminderPending'];
      if (!_isFieldValueDelete(v)) task.reminderPending = v as bool;
    }
  }

  /// Convert HiveTask to Map for compatibility with existing UI code.
  Map<String, dynamic> taskToMap(HiveTask task) {
    final id = task.firestoreId ?? task.key?.toString() ?? '';
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'title': task.title,
      'isDone': task.isDone,
      'isRecurringDaily': task.isRecurringDaily,
      'dateKey': task.dateKey,
      'lastResetOn': task.lastResetOn,
      'createdAt': task.createdAtMillis != null
          ? Timestamp.fromMillisecondsSinceEpoch(task.createdAtMillis!)
          : null,
      'checklist': task.checklist
          ?.map((c) => <String, dynamic>{'text': c.text, 'isDone': c.isDone})
          .toList(),
      'reminderHour': task.reminderHour,
      'reminderMinute': task.reminderMinute,
      'remindAt': task.remindAtMillis != null
          ? Timestamp.fromMillisecondsSinceEpoch(task.remindAtMillis!)
          : null,
      'reminderPending': task.reminderPending,
      'doneByDate': task.doneByDate,
      'checklistDoneByDate': task.checklistDoneByDate,
    };
  }
}
