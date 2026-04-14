import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import 'firestore_update_utils.dart';
import 'isar/app_isar_io.dart';
import 'isar/task_doc.dart';
import 'models/local_task.dart';
import 'task_local_store.dart';

/// Clears shared app Isar (tasks + journals) on sign-out.
Future<void> clearTaskIsarOnLogout() => clearAppIsarOnLogout();

Future<Isar> _ensureIsarOpen() => ensureAppIsarOpen();

String? _encodeBoolMap(Map<String, bool>? m) =>
    m == null ? null : jsonEncode(m);

Map<String, bool>? _decodeDoneByDate(String? json) {
  if (json == null || json.isEmpty) return null;
  final raw = jsonDecode(json);
  if (raw is! Map) return null;
  return raw.map((k, v) => MapEntry(k.toString(), v == true));
}

String? _encodeChecklistDoneByDate(Map<String, List<bool>>? m) {
  if (m == null) return null;
  return jsonEncode(
    m.map((k, v) => MapEntry(k, v)),
  );
}

Map<String, List<bool>>? _decodeChecklistDoneByDate(String? json) {
  if (json == null || json.isEmpty) return null;
  final raw = jsonDecode(json);
  if (raw is! Map) return null;
  final out = <String, List<bool>>{};
  for (final e in raw.entries) {
    final v = e.value;
    if (v is List) {
      out[e.key.toString()] = v.map((x) => x == true).toList();
    }
  }
  return out;
}

TaskDoc _taskDocFromFirestore(String docId, Map<String, dynamic> data) {
  final rawChecklist = data['checklist'];
  List<TaskCheckItem>? checklist;
  if (rawChecklist is List) {
    checklist = rawChecklist.map((e) {
      if (e is Map) {
        final item = TaskCheckItem()
          ..text = (e['text'] as String?) ?? ''
          ..isDone = (e['isDone'] as bool?) ?? false;
        return item;
      }
      return TaskCheckItem()
        ..text = ''
        ..isDone = false;
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

  int? createdAtMillis;
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) {
    createdAtMillis = createdAt.millisecondsSinceEpoch;
  }

  final streakDay = (data['recurringStreakRewardDay'] as num?)?.toInt() ?? 1;

  return TaskDoc()
    ..docKey = docId
    ..title = (data['title'] as String?) ?? 'Untitled'
    ..isDone = (data['isDone'] as bool?) ?? false
    ..isRecurringDaily = (data['isRecurringDaily'] as bool?) ?? false
    ..dateKey = data['dateKey'] as String?
    ..lastResetOn = data['lastResetOn'] as String?
    ..completedOnDayKey = data['completedOnDayKey'] as String?
    ..createdAtMillis = createdAtMillis
    ..checklist = checklist
    ..reminderHour = data['reminderHour'] as int?
    ..reminderMinute = data['reminderMinute'] as int?
    ..remindAtMillis = remindAtMillis
    ..reminderPending = (data['reminderPending'] as bool?) ?? false
    ..reminderSuperImportant =
        (data['reminderSuperImportant'] as bool?) ?? false
    ..doneByDateJson = _encodeBoolMap(doneByDate)
    ..checklistDoneByDateJson = _encodeChecklistDoneByDate(checklistDoneByDate)
    ..recurringStreakRewardDay = streakDay.clamp(1, 7)
    ..recurringStreakLastPaidDayKey =
        data['recurringStreakLastPaidDayKey'] as String?
    ..lastTaskRewardDayKey = data['lastTaskRewardDayKey'] as String?;
}

LocalTask _localTaskFromDoc(TaskDoc d) {
  return LocalTask(
    firestoreId: d.docKey.startsWith('temp_') ? null : d.docKey,
    storageKey: d.docKey,
    title: d.title,
    isDone: d.isDone,
    isRecurringDaily: d.isRecurringDaily,
    dateKey: d.dateKey,
    lastResetOn: d.lastResetOn,
    completedOnDayKey: d.completedOnDayKey,
    createdAtMillis: d.createdAtMillis,
    checklist: d.checklist
        ?.map(
          (c) => TaskChecklistItem(text: c.text, isDone: c.isDone),
        )
        .toList(),
    reminderHour: d.reminderHour,
    reminderMinute: d.reminderMinute,
    remindAtMillis: d.remindAtMillis,
    reminderPending: d.reminderPending,
    reminderSuperImportant: d.reminderSuperImportant,
    doneByDate: _decodeDoneByDate(d.doneByDateJson),
    checklistDoneByDate: _decodeChecklistDoneByDate(d.checklistDoneByDateJson),
    recurringStreakRewardDay: d.recurringStreakRewardDay,
    recurringStreakLastPaidDayKey: d.recurringStreakLastPaidDayKey,
    lastTaskRewardDayKey: d.lastTaskRewardDayKey,
  );
}

TaskDoc _taskDocFromLocal(LocalTask t) {
  return TaskDoc()
    ..docKey = t.storageKey
    ..title = t.title
    ..isDone = t.isDone
    ..isRecurringDaily = t.isRecurringDaily
    ..dateKey = t.dateKey
    ..lastResetOn = t.lastResetOn
    ..completedOnDayKey = t.completedOnDayKey
    ..createdAtMillis = t.createdAtMillis
    ..checklist = t.checklist
        ?.map(
          (c) => TaskCheckItem()
            ..text = c.text
            ..isDone = c.isDone,
        )
        .toList()
    ..reminderHour = t.reminderHour
    ..reminderMinute = t.reminderMinute
    ..remindAtMillis = t.remindAtMillis
    ..reminderPending = t.reminderPending
    ..reminderSuperImportant = t.reminderSuperImportant
    ..doneByDateJson = _encodeBoolMap(t.doneByDate)
    ..checklistDoneByDateJson = _encodeChecklistDoneByDate(
      t.checklistDoneByDate,
    )
    ..recurringStreakRewardDay = t.recurringStreakRewardDay
    ..recurringStreakLastPaidDayKey = t.recurringStreakLastPaidDayKey
    ..lastTaskRewardDayKey = t.lastTaskRewardDayKey;
}

/// Mobile: Isar as primary store; Firestore `snapshots()` runs in parallel and
/// merges server state into Isar. Writes update Isar first where applicable.
class TaskStore implements TaskLocalStore {
  TaskStore({
    required this.userId,
    required this.tasksRef,
  });

  final String userId;
  final CollectionReference<Map<String, dynamic>> tasksRef;

  Isar? _isar;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;

  /// Rebuild UI when any [TaskDoc] changes.
  Stream<void> get changes {
    final isar = _isar;
    if (isar == null) {
      return const Stream<void>.empty();
    }
    return isar.taskDocs.where().watchLazy(fireImmediately: true);
  }

  /// Opens Isar and subscribes to Firestore immediately (no wait for first snapshot).
  Future<void> init() async {
    _isar = await _ensureIsarOpen();

    await _firebaseSub?.cancel();
    _firebaseSub = tasksRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          _onRemoteSnapshot,
          onError: (_) {},
        );
  }

  Future<void> _onRemoteSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final isar = _isar;
    if (isar == null) return;

    await isar.writeTxn(() async {
      if (snap.docChanges.isEmpty) {
        for (final doc in snap.docs) {
          await _upsertFirestoreDoc(isar, doc.id, doc.data());
        }
        return;
      }

      for (final change in snap.docChanges) {
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            final doc = change.doc;
            if (!doc.exists) {
              continue;
            }
            final data = doc.data();
            if (data == null) {
              continue;
            }
            await _upsertFirestoreDoc(isar, doc.id, data);
            break;
          case DocumentChangeType.removed:
            final id = change.doc.id;
            if (id.startsWith('temp_')) {
              break;
            }
            final existing =
                await isar.taskDocs.filter().docKeyEqualTo(id).findFirst();
            if (existing != null) {
              await isar.taskDocs.delete(existing.id);
            }
            break;
        }
      }
    });
  }

  Future<void> _upsertFirestoreDoc(
    Isar isar,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final row = _taskDocFromFirestore(docId, data);
    final existing =
        await isar.taskDocs.filter().docKeyEqualTo(docId).findFirst();
    if (existing != null) {
      row.id = existing.id;
    }
    await isar.taskDocs.put(row);
  }

  void dispose() {
    unawaited(_firebaseSub?.cancel());
    _firebaseSub = null;
  }

  /// Add task: Isar first (temp id), then Firestore; then replace row with server id.
  Future<String?> addTask(Map<String, dynamic> taskData) async {
    final isar = _isar;
    if (isar == null) {
      throw StateError('TaskStore not initialized');
    }

    final createdAt = (taskData['createdAt'] as Timestamp?) ?? Timestamp.now();
    final tempKey = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final pendingDoc = _taskDocFromFirestore(tempKey, taskData)
      ..createdAtMillis = createdAt.millisecondsSinceEpoch;
    final local = _localTaskFromDoc(pendingDoc);

    await isar.writeTxn(() async {
      await isar.taskDocs.put(_taskDocFromLocal(local));
    });

    try {
      final docRef = await tasksRef.add(taskData);
      await isar.writeTxn(() async {
        final tempRow =
            await isar.taskDocs.filter().docKeyEqualTo(tempKey).findFirst();
        if (tempRow != null) {
          await isar.taskDocs.delete(tempRow.id);
        }
        final fromServer = _taskDocFromFirestore(docRef.id, taskData);
        fromServer.createdAtMillis = createdAt.millisecondsSinceEpoch;
        final existing =
            await isar.taskDocs.filter().docKeyEqualTo(docRef.id).findFirst();
        if (existing != null) {
          fromServer.id = existing.id;
        }
        await isar.taskDocs.put(fromServer);
      });
      return docRef.id;
    } catch (e) {
      await isar.writeTxn(() async {
        final tempRow =
            await isar.taskDocs.filter().docKeyEqualTo(tempKey).findFirst();
        if (tempRow != null) {
          await isar.taskDocs.delete(tempRow.id);
        }
      });
      rethrow;
    }
  }

  List<LocalTask> getAllTasks() {
    final isar = _isar;
    if (isar == null) {
      return const [];
    }
    final docs = isar.taskDocs.where().findAllSync();
    final tasks = docs.map(_localTaskFromDoc).toList();
    tasks.sort((a, b) {
      final aMs = a.createdAtMillis ?? 0;
      final bMs = b.createdAtMillis ?? 0;
      return bMs.compareTo(aMs);
    });
    return tasks;
  }

  String getTaskId(LocalTask task) {
    return task.firestoreId ?? task.storageKey;
  }

  LocalTask? getTask(String id) {
    final isar = _isar;
    if (isar == null) return null;
    final row = isar.taskDocs.filter().docKeyEqualTo(id).findFirstSync();
    return row == null ? null : _localTaskFromDoc(row);
  }

  Future<void> updateTask(
    String id,
    Map<String, dynamic> updateData,
  ) async {
    final isar = _isar;
    if (isar == null) return;

    final row = isar.taskDocs.filter().docKeyEqualTo(id).findFirstSync();
    if (row == null) return;

    final task = _localTaskFromDoc(row);
    _applyUpdateToTask(task, updateData);
    final updated = _taskDocFromLocal(task);
    updated.id = row.id;
    updated.docKey = row.docKey;

    await isar.writeTxn(() async {
      await isar.taskDocs.put(updated);
    });

    final firestoreId = task.firestoreId ?? id;
    if (firestoreId.startsWith('temp_')) {
      return;
    }
    unawaited(
      tasksRef
          .doc(firestoreId)
          .update(flattenFirestoreUpdateData(updateData))
          .catchError((Object e, StackTrace st) {
        log(
          'Firestore update failed for $firestoreId',
          error: e,
          stackTrace: st,
          name: 'TaskStore',
        );
      }),
    );
  }

  Future<void> deleteTask(String id) async {
    final isar = _isar;
    if (isar == null) return;

    final row = isar.taskDocs.filter().docKeyEqualTo(id).findFirstSync();
    if (row == null) return;

    final serverDocId =
        row.docKey.startsWith('temp_') ? null : row.docKey;

    await isar.writeTxn(() async {
      await isar.taskDocs.delete(row.id);
    });

    if (serverDocId == null) {
      return;
    }
    try {
      await tasksRef.doc(serverDocId).delete();
    } catch (_) {}
  }

  void _applyUpdateToTask(LocalTask task, Map<String, dynamic> updateData) {
    if (updateData.containsKey('title')) {
      final v = updateData['title'];
      if (!isFirestoreFieldValueDelete(v)) {
        task.title = v as String;
      }
    }
    if (updateData.containsKey('isDone')) {
      final v = updateData['isDone'];
      if (!isFirestoreFieldValueDelete(v)) {
        task.isDone = v as bool;
      }
    }
    if (updateData.containsKey('isRecurringDaily')) {
      final v = updateData['isRecurringDaily'];
      if (!isFirestoreFieldValueDelete(v)) {
        task.isRecurringDaily = v as bool;
      }
    }
    if (updateData.containsKey('checklist')) {
      final raw = updateData['checklist'];
      if (isFirestoreFieldValueDelete(raw)) {
        task.checklist = null;
      } else if (raw is List) {
        task.checklist = raw.map((e) {
          if (e is Map) {
            return TaskChecklistItem(
              text: (e['text'] as String?) ?? '',
              isDone: (e['isDone'] as bool?) ?? false,
            );
          }
          return TaskChecklistItem(text: '', isDone: false);
        }).toList();
      }
    }
    if (updateData.containsKey('doneByDate')) {
      final raw = updateData['doneByDate'];
      if (isFirestoreFieldValueDelete(raw)) {
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
      if (isFirestoreFieldValueDelete(raw)) {
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
    if (updateData.containsKey('completedOnDayKey')) {
      final v = updateData['completedOnDayKey'];
      task.completedOnDayKey =
          isFirestoreFieldValueDelete(v) ? null : v as String?;
    }
    if (updateData.containsKey('reminderHour')) {
      final v = updateData['reminderHour'];
      task.reminderHour = isFirestoreFieldValueDelete(v) ? null : v as int?;
    }
    if (updateData.containsKey('reminderMinute')) {
      final v = updateData['reminderMinute'];
      task.reminderMinute = isFirestoreFieldValueDelete(v) ? null : v as int?;
    }
    if (updateData.containsKey('remindAt')) {
      final v = updateData['remindAt'];
      task.remindAtMillis = isFirestoreFieldValueDelete(v)
          ? null
          : (v is Timestamp ? v.millisecondsSinceEpoch : null);
    }
    if (updateData.containsKey('reminderPending')) {
      final v = updateData['reminderPending'];
      if (!isFirestoreFieldValueDelete(v)) {
        task.reminderPending = v as bool;
      }
    }
    if (updateData.containsKey('reminderSuperImportant')) {
      final v = updateData['reminderSuperImportant'];
      task.reminderSuperImportant = isFirestoreFieldValueDelete(v)
          ? false
          : (v as bool?) ?? false;
    }
    if (updateData.containsKey('recurringStreakRewardDay')) {
      final v = updateData['recurringStreakRewardDay'];
      if (!isFirestoreFieldValueDelete(v)) {
        task.recurringStreakRewardDay =
            ((v as num?)?.toInt() ?? 1).clamp(1, 7);
      }
    }
    if (updateData.containsKey('recurringStreakLastPaidDayKey')) {
      final v = updateData['recurringStreakLastPaidDayKey'];
      task.recurringStreakLastPaidDayKey =
          isFirestoreFieldValueDelete(v) ? null : v as String?;
    }
    if (updateData.containsKey('lastTaskRewardDayKey')) {
      final v = updateData['lastTaskRewardDayKey'];
      task.lastTaskRewardDayKey =
          isFirestoreFieldValueDelete(v) ? null : v as String?;
    }
  }

  Map<String, dynamic> taskToMap(LocalTask task) {
    final id = task.firestoreId ?? task.storageKey;
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'title': task.title,
      'isDone': task.isDone,
      'isRecurringDaily': task.isRecurringDaily,
      'dateKey': task.dateKey,
      'lastResetOn': task.lastResetOn,
      'completedOnDayKey': task.completedOnDayKey,
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
      'reminderSuperImportant': task.reminderSuperImportant,
      'doneByDate': task.doneByDate,
      'checklistDoneByDate': task.checklistDoneByDate,
      'recurringStreakRewardDay': task.recurringStreakRewardDay,
      'recurringStreakLastPaidDayKey': task.recurringStreakLastPaidDayKey,
      'lastTaskRewardDayKey': task.lastTaskRewardDayKey,
    };
  }
}
