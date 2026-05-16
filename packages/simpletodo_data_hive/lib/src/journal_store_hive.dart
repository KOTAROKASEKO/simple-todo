import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart';
import 'hive_box_registry.dart';

class JournalStore implements JournalLocalStore {
  JournalStore({required this.journalRef});

  @override
  final CollectionReference<Map<String, dynamic>> journalRef;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;
  Box<Map>? _box;
  Box<Map>? _opsBox;
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};
  Future<void>? _journalSeedChain;

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<void> init() async {
    final safePathKey = journalRef.path.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final name = 'hive_journal_$safePathKey';
    final opsName = 'hive_journal_ops_$safePathKey';
    registerHiveBoxName(name);
    registerHiveBoxName(opsName);
    _box = await Hive.openBox<Map>(name);
    _opsBox = await Hive.openBox<Map>(opsName);
    await _applyPendingOpsToLocal();
    await _firebaseSub?.cancel();
    _firebaseSub = journalRef.snapshots().listen((_) async {
      await _seedFromFirestore();
      await _drainPendingOps();
      _changesController.add(null);
    });
    _changesController.add(null);
    unawaited(_bootstrapJournalRemote());
  }

  Future<void> _bootstrapJournalRemote() async {
    try {
      await _seedFromFirestore();
    } catch (_) {
      // Offline / timeout: keep existing Hive journal cache.
    }
    await _drainPendingOps();
    _changesController.add(null);
  }

  Future<void> _seedFromFirestore() async {
    final prev = _journalSeedChain;
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }
    final mine = _seedJournalFromFirestoreBody();
    _journalSeedChain = mine;
    try {
      await mine;
    } finally {
      if (identical(_journalSeedChain, mine)) {
        _journalSeedChain = null;
      }
    }
  }

  Future<void> _seedJournalFromFirestoreBody() async {
    final box = _box;
    if (box == null) return;
    try {
      final snap = await journalRef.orderBy('createdAt', descending: true).get();
      await box.clear();
      for (final doc in snap.docs) {
        await box.put(doc.id, _toHiveMap(doc.data()));
      }
      await _applyPendingOpsToLocal();
    } catch (_) {
      // Offline / timeout: do not clear local journal.
    }
  }

  @override
  void dispose() {
    unawaited(_firebaseSub?.cancel());
    _firebaseSub = null;
    unawaited(_changesController.close());
  }

  @override
  List<LocalJournalEntry> getAllJournalEntries() {
    final box = _box;
    if (box == null) return const [];
    final out = box.toMap().entries.map((entry) {
      return _entryFromMap(entry.key.toString(), Map<String, dynamic>.from(entry.value));
    }).toList();
    out.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    return out;
  }

  @override
  Future<void> ingestAfterRemoteCreate(String docId, Map<String, dynamic> data) async {
    final box = _box;
    if (box == null) return;
    await box.put(docId, _toHiveMap(data));
    _changesController.add(null);
  }

  @override
  Future<void> updateJournal(String id, Map<String, dynamic> updateData) async {
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
  Future<void> deleteJournal(String id) async {
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
    final opsBox = _opsBox;
    if (opsBox == null) return '';
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$type';
    await opsBox.put(opId, <String, dynamic>{
      'type': type,
      'docId': docId,
      'data': _toHiveMap(data),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    return opId;
  }

  Future<void> _removeOp(String opId) async {
    final opsBox = _opsBox;
    if (opsBox == null || opId.isEmpty) return;
    await opsBox.delete(opId);
  }

  Future<void> _sendUpdateOp(
    String opId,
    String docId,
    Map<String, dynamic> updateData,
  ) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await journalRef.doc(docId).update(updateData);
      await _removeOp(opId);
    } catch (_) {
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _sendDeleteOp(String opId, String docId) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await journalRef.doc(docId).delete();
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
      if (type == 'update') {
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
      if (type == 'update') {
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

  LocalJournalEntry _entryFromMap(String id, Map<String, dynamic> data) {
    double sortOrder = 0;
    final order = data['order'];
    if (order is num) {
      sortOrder = order.toDouble();
    } else if (data['createdAt'] is Timestamp) {
      sortOrder = (data['createdAt'] as Timestamp).millisecondsSinceEpoch.toDouble();
    }
    int? createdAtMillis;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      createdAtMillis = createdAt.millisecondsSinceEpoch;
    } else if (createdAt is int) {
      createdAtMillis = createdAt;
    }
    final imagePathsRaw = data['imagePaths'];
    final imagePaths = imagePathsRaw is List
        ? imagePathsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : null;
    final aiRaw = data['aiReflection'];
    final aiMap = aiRaw is Map
        ? Map<String, dynamic>.from(aiRaw.map((k, v) => MapEntry(k.toString(), v)))
        : null;
    return LocalJournalEntry(
      id: id,
      content: (data['content'] ?? '').toString(),
      category: ((data['category'] as String?) ?? 'diary').toLowerCase(),
      sortOrder: sortOrder,
      createdAtMillis: createdAtMillis,
      imagePaths: imagePaths,
      imagePathLegacy: data['imagePath'] as String?,
      aiReflection: aiMap,
      journalAiFeedbackRequested:
          (data['journalAiFeedbackRequested'] as bool?) ?? false,
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
}
