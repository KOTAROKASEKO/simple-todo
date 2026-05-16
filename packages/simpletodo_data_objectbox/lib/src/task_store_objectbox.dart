import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart';
import '../objectbox.g.dart' show ObKv_, openStore;
import 'entities.dart' show ObKv;

import 'objectbox_lifecycle_io.dart' as ob;

const String _kTaskPrefix = 't:';
const String _kOpPrefix = 'o:';

class TaskStore implements TaskLocalStore {
  TaskStore({required this.userId, required this.tasksRef});

  @override
  final String userId;
  @override
  final CollectionReference<Map<String, dynamic>> tasksRef;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;
  Store? _store;
  Box<ObKv>? _box;
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    final path = p.join(base.path, 'st_ob_user_tasks', userId);
    await Directory(path).create(recursive: true);
    ob.registerObjectBoxDataPath(path);
    _store = await openStore(
      maxReaders: 1,
      maxDBSizeInKB: 0,
      maxDataSizeInKB: 0,
      directory: path,
    );
    ob.registerObjectBoxStore(_store!);
    _box = _store!.box<ObKv>();
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
      // Offline / timeout: keep existing ObjectBox cache.
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
      final sanitized = _toObMap(doc.data());
      if (!_isValidTaskMap(sanitized)) continue;
      await _putMap(box, '$_kTaskPrefix${doc.id}', sanitized);
    }
    final toDelete = <String>[];
    for (final row in _allWithKeyPrefix(box, _kTaskPrefix)) {
      final id = row.k.substring(_kTaskPrefix.length);
      if (id.startsWith('temp_')) continue;
      if (!remoteIds.contains(id)) {
        toDelete.add(row.k);
      }
    }
    for (final k in toDelete) {
      await _removeKey(box, k);
    }
    await _applyPendingOpsToLocal();
  }

  @override
  void dispose() {
    if (_store != null) {
      ob.unregisterObjectBoxStore(_store!);
      try {
        _store!.close();
      } catch (_) {}
      _store = null;
    }
    _box = null;
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
      await _putMap(
        box,
        '$_kTaskPrefix$stableDocId',
        _toObMap(taskData),
      );
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
    final out = <LocalTask>[];
    for (final row in _allWithKeyPrefix(box, _kTaskPrefix)) {
      final id = row.k.substring(_kTaskPrefix.length);
      final m = _decodeMap(row.v);
      if (m == null) continue;
      if (!_isValidTaskMap(m)) continue;
      out.add(_localTaskFromMap(id, m));
    }
    return out
        .where((task) => task.title.trim().isNotEmpty)
        .toList();
  }

  @override
  String getTaskId(LocalTask task) => task.firestoreId ?? task.storageKey;

  @override
  LocalTask? getTask(String id) {
    final box = _box;
    if (box == null) return null;
    final row = _getByKey(box, '$_kTaskPrefix$id');
    if (row == null) return null;
    final m = _decodeMap(row.v);
    if (m == null) return null;
    if (!_isValidTaskMap(m)) return null;
    return _localTaskFromMap(id, m);
  }

  @override
  Future<void> updateTask(String id, Map<String, dynamic> updateData) async {
    final box = _box;
    if (box != null) {
      final current = Map<String, dynamic>.from(
        _decodeMap(
              _getByKey(box, '$_kTaskPrefix$id')?.v,
            ) ??
            <String, dynamic>{},
      );
      for (final e in updateData.entries) {
        current[e.key] = _toObValue(e.value);
      }
      await _putMap(box, '$_kTaskPrefix$id', current);
      _changesController.add(null);
    }
    final opId = await _enqueueOp('update', id, updateData);
    unawaited(_sendUpdateOp(opId, id, updateData));
  }

  @override
  Future<void> deleteTask(String id) async {
    final box = _box;
    if (box != null) {
      await _removeKey(box, '$_kTaskPrefix$id');
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
    final box = _box;
    if (box == null) return;
    final payload = <String, dynamic>{
      'type': type,
      'docId': docId,
      'data': _toObMap(data),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _putString(box, '$_kOpPrefix$opId', jsonEncode(payload));
  }

  Future<void> _removeOp(String opId) async {
    final box = _box;
    if (box == null || opId.isEmpty) return;
    await _removeKey(box, '$_kOpPrefix$opId');
  }

  Future<void> _sendCreateOp(
    String opId,
    String localDocId,
    Map<String, dynamic> taskData,
  ) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      final docRef = tasksRef.doc(localDocId);
      await docRef.set(
        _toFirestoreWriteData(taskData),
        SetOptions(merge: true),
      );
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
      await tasksRef.doc(docId).update(
            flattenFirestoreUpdateData(
              _toFirestoreWriteData(updateData),
            ),
          );
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
      final box = _box;
      if (box == null) return;
      final entries = _allWithKeyPrefix(box, _kOpPrefix)
        ..sort((a, b) => a.k.compareTo(b.k));
      for (final row in entries) {
        final opId = row.k.substring(_kOpPrefix.length);
        final raw = _decodeMap(row.v);
        if (raw == null) continue;
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
    if (box == null) return;
    final entries = _allWithKeyPrefix(box, _kOpPrefix)
      ..sort((a, b) => a.k.compareTo(b.k));
    for (final row in entries) {
      final raw = _decodeMap(row.v);
      if (raw == null) continue;
      final type = (raw['type'] as String?) ?? '';
      final docId = (raw['docId'] as String?) ?? '';
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      if (type == 'create') {
        await _putMap(box, '$_kTaskPrefix$docId', data);
      } else if (type == 'update') {
        final current = Map<String, dynamic>.from(
          _decodeMap(_getByKey(box, '$_kTaskPrefix$docId')?.v) ??
              <String, dynamic>{},
        );
        data.forEach((k, v) {
          current[k] = v;
        });
        await _putMap(box, '$_kTaskPrefix$docId', current);
      } else if (type == 'delete') {
        await _removeKey(box, '$_kTaskPrefix$docId');
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
      if (task.checklistDoneByDate != null) 'checklistDoneByDate': task.checklistDoneByDate,
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
          ? Map<String, bool>.from(
              (data['doneByDate'] as Map).map(
                (k, v) => MapEntry(k.toString(), v == true),
              ),
            )
          : null,
      checklistDoneByDate: (data['checklistDoneByDate'] is Map)
          ? (data['checklistDoneByDate'] as Map).map((k, v) {
              final list = (v is List) ? v.map((item) => item == true).toList() : <bool>[];
              return MapEntry(k.toString(), list);
            })
          : null,
      recurringStreakRewardDay: ((data['recurringStreakRewardDay'] as num?)?.toInt() ?? 1),
      recurringStreakLastPaidDayKey: data['recurringStreakLastPaidDayKey'] as String?,
      lastTaskRewardDayKey: data['lastTaskRewardDayKey'] as String?,
    );
  }

  Map<String, dynamic> _toObMap(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final e in data.entries) {
      out[e.key] = _toObValue(e.value);
    }
    return out;
  }

  Object? _toObValue(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (isFirestoreFieldValueDelete(value)) return null;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _toObValue(v);
      });
      return out;
    }
    if (value is List) {
      return value.map(_toObValue).toList(growable: false);
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

// --- KVP helpers (ObKv) ---

List<ObKv> _allWithKeyPrefix(Box<ObKv> box, String prefix) {
  final q = box.query(ObKv_.k.startsWith(prefix)).build();
  final list = q.find();
  q.close();
  return list;
}

ObKv? _getByKey(Box<ObKv> box, String key) {
  final q = box.query(ObKv_.k.equals(key)).build();
  final first = q.findFirst();
  q.close();
  return first;
}

Map<String, dynamic>? _decodeMap(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    final o = jsonDecode(s);
    if (o is Map) {
      return Map<String, dynamic>.from(
        o.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
  } catch (_) {}
  return null;
}

Future<void> _putMap(Box<ObKv> box, String key, Map<String, dynamic> m) {
  return _putString(box, key, jsonEncode(m));
}

Future<void> _putString(Box<ObKv> box, String key, String v) async {
  final found = _getByKey(box, key);
  if (found == null) {
    box.put(ObKv()..k = key..v = v);
  } else {
    found.v = v;
    box.put(found);
  }
}

Future<void> _removeKey(Box<ObKv> box, String key) async {
  final found = _getByKey(box, key);
  if (found != null) {
    box.remove(found.id);
  }
}
