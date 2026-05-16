import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart';
import 'hive_box_registry.dart';

class TaskStore implements TaskLocalStore {
  TaskStore({required this.userId, required this.tasksRef});

  @override
  final String userId;
  @override
  final CollectionReference<Map<String, dynamic>> tasksRef;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;
  Box<Map>? _box;
  Box<Map>? _opsBox;
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<void> init() async {
    final name = 'hive_tasks_$userId';
    final opsName = 'hive_task_ops_$userId';
    registerHiveBoxName(name);
    registerHiveBoxName(opsName);
    _box = await Hive.openBox<Map>(name);
    _opsBox = await Hive.openBox<Map>(opsName);
    await _applyPendingOpsToLocal();
    await _firebaseSub?.cancel();
    _firebaseSub = tasksRef.snapshots().listen((_) async {
      await _seedFromFirestore();
      await _drainPendingOps();
      _changesController.add(null);
    });
    _changesController.add(null);
    unawaited(_bootstrapTasksRemote());
  }

  /// Firestore seed + outbound queue; does not block [init] so local tasks show immediately.
  Future<void> _bootstrapTasksRemote() async {
    try {
      await _seedFromFirestore();
    } catch (_) {
      // Offline / timeout: keep existing Hive cache.
    }
    await _drainPendingOps();
    _changesController.add(null);
  }

  Future<void> _seedFromFirestore() async {
    final box = _box;
    if (box == null) return;
    final snap = await tasksRef.get();
    final remoteIds = <String>{};
    for (final doc in snap.docs) {
      remoteIds.add(doc.id);
      final sanitized = _toHiveMap(doc.data());
      if (!_isValidTaskMap(sanitized)) continue;
      await box.put(doc.id, sanitized);
    }
    final toDelete = <String>[];
    for (final key in box.keys) {
      final id = key.toString();
      if (id.startsWith('temp_')) continue;
      if (!remoteIds.contains(id)) {
        toDelete.add(id);
      }
    }
    for (final id in toDelete) {
      await box.delete(id);
    }
    await _applyPendingOpsToLocal();
  }

  @override
  void dispose() {
    unawaited(_firebaseSub?.cancel());
    _firebaseSub = null;
    unawaited(_changesController.close());
  }

  @override
  Future<String?> addTask(Map<String, dynamic> taskData) async {
    final title = (taskData['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final opId = '${DateTime.now().microsecondsSinceEpoch}_create';
    final stableDocId = 'local_$opId';
    final box = _box;
    if (box != null) {
      await box.put(stableDocId, _toHiveMap(taskData));
      _changesController.add(null);
    }
    await _enqueueOpWithId(
      opId,
      type: 'create',
      docId: stableDocId,
      data: taskData,
    );
    unawaited(_sendCreateOp(opId, stableDocId, taskData));
    return stableDocId;
  }

  @override
  List<LocalTask> getAllTasks() {
    final box = _box;
    if (box == null) return const [];
    return box.toMap().entries
        .map((entry) => _localTaskFromMap(
              entry.key.toString(),
              Map<String, dynamic>.from(entry.value),
            ))
        .where((task) => task.title.trim().isNotEmpty)
        .toList();
  }

  @override
  String getTaskId(LocalTask task) => task.firestoreId ?? task.storageKey;

  @override
  LocalTask? getTask(String id) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(id);
    if (raw == null) return null;
    final data = Map<String, dynamic>.from(raw);
    if (!_isValidTaskMap(data)) return null;
    return _localTaskFromMap(id, data);
  }

  @override
  Future<void> updateTask(String id, Map<String, dynamic> updateData) async {
    final box = _box;
    if (box != null) {
      final current = Map<String, dynamic>.from(box.get(id) ?? <String, dynamic>{});
      for (final e in updateData.entries) {
        current[e.key] = _toHiveValue(e.value);
      }
      await box.put(id, current);
      _changesController.add(null);
    }
    final opId = await _enqueueOp('update', id, updateData);
    unawaited(_sendUpdateOp(opId, id, updateData));
  }

  @override
  Future<void> deleteTask(String id) async {
    final box = _box;
    if (box != null) {
      await box.delete(id);
      _changesController.add(null);
    }
    final opId = await _enqueueOp('delete', id, const <String, dynamic>{});
    unawaited(_sendDeleteOp(opId, id));
  }

  Future<String> _enqueueOp(
    String type,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$type';
    await _enqueueOpWithId(opId, type: type, docId: docId, data: data);
    return opId;
  }

  Future<void> _enqueueOpWithId(
    String opId, {
    required String type,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final opsBox = _opsBox;
    if (opsBox == null) return;
    await opsBox.put(opId, <String, dynamic>{
      'type': type,
      'docId': docId,
      'data': _toHiveMap(data),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _removeOp(String opId) async {
    final opsBox = _opsBox;
    if (opsBox == null || opId.isEmpty) return;
    await opsBox.delete(opId);
  }

  Future<void> _sendCreateOp(
    String opId,
    String localDocId,
    Map<String, dynamic> taskData,
  ) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      final docRef = tasksRef.doc(localDocId);
      await docRef.set(_toFirestoreWriteData(taskData), SetOptions(merge: true));
      await _removeOp(opId);
      _changesController.add(null);
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
      await tasksRef
          .doc(docId)
          .update(flattenFirestoreUpdateData(_toFirestoreWriteData(updateData)));
      await _removeOp(opId);
    } catch (_) {
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _sendDeleteOp(String opId, String docId) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    if (docId.startsWith('temp_')) {
      await _removeOp(opId);
      return;
    }
    try {
      await tasksRef.doc(docId).delete();
      await _removeOp(opId);
    } catch (_) {
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _drainPendingOps() async {
    if (_drainingPendingOps) return;
    _drainingPendingOps = true;
    try {
    final opsBox = _opsBox;
    if (opsBox == null) return;
    final entries = opsBox.toMap().entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    for (final e in entries) {
      final opId = e.key.toString();
      final raw = Map<String, dynamic>.from(e.value);
      final type = (raw['type'] as String?) ?? '';
      final docId = (raw['docId'] as String?) ?? '';
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
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
    final box = _box;
    final opsBox = _opsBox;
    if (box == null || opsBox == null) return;
    final entries = opsBox.toMap().entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    for (final e in entries) {
      final raw = Map<String, dynamic>.from(e.value);
      final type = (raw['type'] as String?) ?? '';
      final docId = (raw['docId'] as String?) ?? '';
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      if (type == 'create') {
        await box.put(docId, data);
      } else if (type == 'update') {
        final current = Map<String, dynamic>.from(box.get(docId) ?? <String, dynamic>{});
        data.forEach((k, v) {
          current[k] = v;
        });
        await box.put(docId, current);
      } else if (type == 'delete') {
        await box.delete(docId);
      }
    }
  }

  @override
  Map<String, dynamic> taskToMap(LocalTask task) {
    return <String, dynamic>{
      'title': task.title,
      'isDone': task.isDone,
      'isRecurringDaily': task.isRecurringDaily,
      if (task.dateKey != null) 'date': task.dateKey,
      if (task.lastResetOn != null) 'lastResetOn': task.lastResetOn,
      if (task.completedOnDayKey != null) 'completedOnDayKey': task.completedOnDayKey,
      if (task.createdAtMillis != null)
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(task.createdAtMillis!),
      if (task.checklist != null)
        'checklist': task.checklist!
            .map((c) => <String, dynamic>{'text': c.text, 'isDone': c.isDone})
            .toList(),
      if (task.reminderHour != null) 'reminderHour': task.reminderHour,
      if (task.reminderMinute != null) 'reminderMinute': task.reminderMinute,
      if (task.remindAtMillis != null) 'remindAtMillis': task.remindAtMillis,
      'reminderPending': task.reminderPending,
      'reminderSuperImportant': task.reminderSuperImportant,
      if (task.doneByDate != null) 'doneByDate': task.doneByDate,
      if (task.checklistDoneByDate != null)
        'checklistDoneByDate': task.checklistDoneByDate,
      'recurringStreakRewardDay': task.recurringStreakRewardDay,
      if (task.recurringStreakLastPaidDayKey != null)
        'recurringStreakLastPaidDayKey': task.recurringStreakLastPaidDayKey,
      if (task.lastTaskRewardDayKey != null)
        'lastTaskRewardDayKey': task.lastTaskRewardDayKey,
    };
  }

  LocalTask _localTaskFromMap(String id, Map<String, dynamic> data) {
    List<TaskChecklistItem>? checklist;
    final checklistRaw = data['checklist'];
    if (checklistRaw is List) {
      checklist = checklistRaw.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return TaskChecklistItem(
          text: (m['text'] ?? '').toString(),
          isDone: (m['isDone'] as bool?) ?? false,
        );
      }).toList();
    }

    int? createdAtMillis;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      createdAtMillis = createdAt.millisecondsSinceEpoch;
    } else if (createdAt is int) {
      createdAtMillis = createdAt;
    }

    return LocalTask(
      firestoreId: id.startsWith('temp_') ? null : id,
      storageKey: id,
      title: (data['title'] ?? '').toString(),
      isDone: (data['isDone'] as bool?) ?? false,
      isRecurringDaily: (data['isRecurringDaily'] as bool?) ?? false,
      dateKey: (data['dateKey'] ?? data['date']) as String?,
      lastResetOn: data['lastResetOn'] as String?,
      completedOnDayKey: data['completedOnDayKey'] as String?,
      createdAtMillis: createdAtMillis,
      checklist: checklist,
      reminderHour: (data['reminderHour'] as num?)?.toInt(),
      reminderMinute: (data['reminderMinute'] as num?)?.toInt(),
      remindAtMillis: (data['remindAtMillis'] as num?)?.toInt(),
      reminderPending: (data['reminderPending'] as bool?) ?? false,
      reminderSuperImportant: (data['reminderSuperImportant'] as bool?) ?? false,
      doneByDate: (data['doneByDate'] is Map)
          ? Map<String, bool>.from((data['doneByDate'] as Map).map(
              (k, v) => MapEntry(k.toString(), v == true),
            ))
          : null,
      checklistDoneByDate: (data['checklistDoneByDate'] is Map)
          ? (data['checklistDoneByDate'] as Map).map((k, v) {
              final list = (v is List)
                  ? v.map((item) => item == true).toList()
                  : <bool>[];
              return MapEntry(k.toString(), list);
            })
          : null,
      recurringStreakRewardDay:
          ((data['recurringStreakRewardDay'] as num?)?.toInt() ?? 1),
      recurringStreakLastPaidDayKey:
          data['recurringStreakLastPaidDayKey'] as String?,
      lastTaskRewardDayKey: data['lastTaskRewardDayKey'] as String?,
    );
  }

  Map<String, dynamic> _toHiveMap(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final e in data.entries) {
      out[e.key] = _toHiveValue(e.value);
    }
    return out;
  }

  Object? _toHiveValue(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (isFirestoreFieldValueDelete(value)) return null;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _toHiveValue(v);
      });
      return out;
    }
    if (value is List) {
      return value.map(_toHiveValue).toList(growable: false);
    }
    if (value is String || value is num || value is bool) return value;
    return value.toString();
  }

  Map<String, dynamic> _toFirestoreWriteData(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final e in data.entries) {
      final k = e.key;
      final v = e.value;
      if ((k == 'createdAt' || k == 'remindAt') && v is num) {
        out[k] = Timestamp.fromMillisecondsSinceEpoch(v.toInt());
        continue;
      }
      out[k] = v;
    }
    return out;
  }

  bool _isValidTaskMap(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().trim();
    return title.isNotEmpty;
  }
}
