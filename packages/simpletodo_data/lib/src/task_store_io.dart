import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:simpletodo_data_core/simpletodo_data_core.dart'
    show
        LocalTask,
        TaskChecklistItem,
        TaskLocalStore,
        flattenFirestoreUpdateData,
        isFirestoreFieldValueDelete;
import 'isar/app_isar_io.dart';
import 'isar/task_doc.dart';


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
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};

  /// Rebuild UI when any [TaskDoc] changes.
  Stream<void> get changes {
    final isar = _isar;
    if (isar == null) {
      return const Stream<void>.empty();
    }
    try {
      return isar.taskDocs.where().watchLazy(fireImmediately: true);
    } on IsarError {
      // App lifecycle can race with disposal/rebuild; avoid crashing UI.
      return const Stream<void>.empty();
    }
  }

  /// Opens Isar and subscribes to Firestore immediately (no wait for first snapshot).
  Future<void> init() async {
    _isar = await _ensureIsarOpen();
    await _drainPendingOps();

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
    await _applyPendingOpsToLocal();
    await _drainPendingOps();
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
    _isar = null;
  }

  /// Add task: Isar first (temp id), then Firestore; then replace row with server id.
  Future<String?> addTask(Map<String, dynamic> taskData) async {
    final isar = _isar;
    if (isar == null) {
      throw StateError('TaskStore not initialized');
    }

    final createdAt = (taskData['createdAt'] as Timestamp?) ?? Timestamp.now();
    final opId = '${DateTime.now().microsecondsSinceEpoch}_create';
    final stableDocId = 'local_$opId';
    final pendingDoc = _taskDocFromFirestore(stableDocId, taskData)
      ..createdAtMillis = createdAt.millisecondsSinceEpoch;
    final local = _localTaskFromDoc(pendingDoc);

    await isar.writeTxn(() async {
      await isar.taskDocs.put(_taskDocFromLocal(local));
    });
    await _enqueuePendingOpWithId(
      opId,
      type: 'create',
      docId: stableDocId,
      data: taskData,
    );
    unawaited(_sendCreateOp(opId, stableDocId, taskData));
    return stableDocId;
  }

  List<LocalTask> getAllTasks() {
    final isar = _isar;
    if (isar == null) {
      return const [];
    }
    try {
      final docs = isar.taskDocs.where().findAllSync();
      final tasks = docs.map(_localTaskFromDoc).toList();
      tasks.sort((a, b) {
        final aMs = a.createdAtMillis ?? 0;
        final bMs = b.createdAtMillis ?? 0;
        return bMs.compareTo(aMs);
      });
      return tasks;
    } on IsarError {
      return const [];
    }
  }

  String getTaskId(LocalTask task) {
    return task.firestoreId ?? task.storageKey;
  }

  LocalTask? getTask(String id) {
    final isar = _isar;
    if (isar == null) return null;
    try {
      final row = isar.taskDocs.filter().docKeyEqualTo(id).findFirstSync();
      return row == null ? null : _localTaskFromDoc(row);
    } on IsarError {
      return null;
    }
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
    final opId = await _enqueuePendingOp(
      type: 'update',
      docId: firestoreId,
      data: updateData,
    );
    unawaited(_sendUpdateOp(opId, firestoreId, updateData));
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
      await _removeOpsForDocId(id);
      return;
    }
    final opId = await _enqueuePendingOp(
      type: 'delete',
      docId: serverDocId,
      data: const <String, dynamic>{},
    );
    unawaited(_sendDeleteOp(opId, serverDocId));
  }

  Future<File> _pendingOpsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/task_pending_ops_$userId.json');
  }

  Future<List<Map<String, dynamic>>> _loadPendingOps() async {
    try {
      final f = await _pendingOpsFile();
      if (!await f.exists()) return <Map<String, dynamic>>[];
      final text = await f.readAsString();
      if (text.trim().isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(text);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _savePendingOps(List<Map<String, dynamic>> ops) async {
    try {
      final f = await _pendingOpsFile();
      await f.writeAsString(jsonEncode(ops));
    } catch (_) {}
  }

  Future<String> _enqueuePendingOp({
    required String type,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$type';
    await _enqueuePendingOpWithId(
      opId,
      type: type,
      docId: docId,
      data: data,
    );
    return opId;
  }

  Future<void> _enqueuePendingOpWithId(
    String opId, {
    required String type,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final ops = await _loadPendingOps();
    ops.add(<String, dynamic>{
      'opId': opId,
      'type': type,
      'docId': docId,
      'data': data,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _savePendingOps(ops);
  }

  Future<void> _removePendingOp(String opId) async {
    final ops = await _loadPendingOps();
    ops.removeWhere((op) => (op['opId'] as String?) == opId);
    await _savePendingOps(ops);
  }

  Future<void> _removeOpsForDocId(String docId) async {
    final ops = await _loadPendingOps();
    ops.removeWhere((op) => (op['docId'] as String?) == docId);
    await _savePendingOps(ops);
  }

  Future<void> _sendCreateOp(
    String opId,
    String localDocId,
    Map<String, dynamic> taskData,
  ) async {
    final isar = _isar;
    if (isar == null) return;
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      final docRef = tasksRef.doc(localDocId);
      await docRef.set(taskData, SetOptions(merge: true));
      await _removePendingOp(opId);
    } catch (_) {
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _sendUpdateOp(
    String opId,
    String docId,
    Map<String, dynamic> updateData,
  ) async {
    if (docId.startsWith('temp_')) return;
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await tasksRef.doc(docId).update(flattenFirestoreUpdateData(updateData));
      await _removePendingOp(opId);
    } catch (e, st) {
      log(
        'Firestore update failed for $docId',
        error: e,
        stackTrace: st,
        name: 'TaskStore',
      );
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _sendDeleteOp(String opId, String docId) async {
    if (docId.startsWith('temp_')) {
      await _removePendingOp(opId);
      return;
    }
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await tasksRef.doc(docId).delete();
      await _removePendingOp(opId);
    } catch (_) {
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _drainPendingOps() async {
    if (_drainingPendingOps) return;
    _drainingPendingOps = true;
    try {
      final ops = await _loadPendingOps()
        ..sort(
          (a, b) => ((a['createdAtMs'] as num?)?.toInt() ?? 0).compareTo(
            (b['createdAtMs'] as num?)?.toInt() ?? 0,
          ),
        );
      for (final op in ops) {
        final opId = (op['opId'] as String?) ?? '';
        final type = (op['type'] as String?) ?? '';
        final docId = (op['docId'] as String?) ?? '';
        final data = op['data'] is Map
            ? Map<String, dynamic>.from(op['data'] as Map)
            : <String, dynamic>{};
        if (type == 'create') {
          await _sendCreateOp(opId, docId, data);
        } else if (type == 'update') {
          await _sendUpdateOp(opId, docId, data);
        } else if (type == 'delete') {
          await _sendDeleteOp(opId, docId);
        }
      }
    } finally {
      _drainingPendingOps = false;
    }
  }

  Future<void> _applyPendingOpsToLocal() async {
    final isar = _isar;
    if (isar == null) return;
    final ops = await _loadPendingOps()
      ..sort(
        (a, b) => ((a['createdAtMs'] as num?)?.toInt() ?? 0).compareTo(
          (b['createdAtMs'] as num?)?.toInt() ?? 0,
        ),
      );
    await isar.writeTxn(() async {
      for (final op in ops) {
        final type = (op['type'] as String?) ?? '';
        final docId = (op['docId'] as String?) ?? '';
        final data = op['data'] is Map
            ? Map<String, dynamic>.from(op['data'] as Map)
            : <String, dynamic>{};
        if (type == 'create') {
          await _upsertFirestoreDoc(isar, docId, data);
        } else if (type == 'update') {
          final row = await isar.taskDocs.filter().docKeyEqualTo(docId).findFirst();
          if (row == null) continue;
          final task = _localTaskFromDoc(row);
          _applyUpdateToTask(task, data);
          final updated = _taskDocFromLocal(task)
            ..id = row.id
            ..docKey = row.docKey;
          await isar.taskDocs.put(updated);
        } else if (type == 'delete') {
          final row = await isar.taskDocs.filter().docKeyEqualTo(docId).findFirst();
          if (row != null) {
            await isar.taskDocs.delete(row.id);
          }
        }
      }
    });
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
