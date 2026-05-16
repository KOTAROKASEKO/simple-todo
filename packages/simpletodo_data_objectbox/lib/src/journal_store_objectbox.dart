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

const String _kJournalPrefix = 'j:';
const String _kJournalOpPrefix = 'jo:';

class JournalStore implements JournalLocalStore {
  JournalStore({required this.journalRef});

  @override
  final CollectionReference<Map<String, dynamic>> journalRef;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;
  Store? _store;
  Box<ObKv>? _box;
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};
  Future<void>? _journalSeedChain;

  String get _storePathKey =>
      journalRef.path.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    final path = p.join(base.path, 'st_ob_journal', _storePathKey);
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
      // Offline / timeout: keep existing ObjectBox journal cache.
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
      for (final k in _allKeyStringsWithPrefix(box, _kJournalPrefix)) {
        await _removeKey(box, k);
      }
      for (final doc in snap.docs) {
        await _putMap(
          box,
          '$_kJournalPrefix${doc.id}',
          _toObMap(doc.data()),
        );
      }
      await _applyPendingOpsToLocal();
    } catch (_) {
      // Offline / timeout: do not wipe local journal keys.
    }
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
  List<LocalJournalEntry> getAllJournalEntries() {
    final box = _box;
    if (box == null) return const [];
    final out = <LocalJournalEntry>[];
    for (final row in _allWithKeyPrefix(box, _kJournalPrefix)) {
      final m = _decodeMap(row.v);
      if (m == null) continue;
      out.add(
        _entryFromMap(
          row.k.substring(_kJournalPrefix.length),
          m,
        ),
      );
    }
    out.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    return out;
  }

  @override
  Future<void> ingestAfterRemoteCreate(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final box = _box;
    if (box == null) return;
    await _putMap(box, '$_kJournalPrefix$docId', _toObMap(data));
    _changesController.add(null);
  }

  @override
  Future<void> updateJournal(String id, Map<String, dynamic> updateData) async {
    final box = _box;
    if (box != null) {
      final current = Map<String, dynamic>.from(
        _decodeMap(
              _getByKey(box, '$_kJournalPrefix$id')?.v,
            ) ??
            <String, dynamic>{},
      );
      for (final e in updateData.entries) {
        current[e.key] = _toObValue(e.value);
      }
      await _putMap(box, '$_kJournalPrefix$id', current);
      _changesController.add(null);
    }
    final opId = await _enqueueOp('update', id, updateData);
    unawaited(_sendUpdateOp(opId, id, updateData));
  }

  @override
  Future<void> deleteJournal(String id) async {
    final box = _box;
    if (box != null) {
      await _removeKey(box, '$_kJournalPrefix$id');
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
    final box = _box;
    if (box == null) return '';
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$type';
    final payload = <String, dynamic>{
      'type': type,
      'docId': docId,
      'data': _toObMap(data),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _putString(box, '$_kJournalOpPrefix$opId', jsonEncode(payload));
    return opId;
  }

  Future<void> _removeOp(String opId) async {
    final box = _box;
    if (box == null || opId.isEmpty) return;
    await _removeKey(box, '$_kJournalOpPrefix$opId');
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
      final box = _box;
      if (box == null) return;
      final entries = _allWithKeyPrefix(box, _kJournalOpPrefix)
        ..sort((a, b) => a.k.compareTo(b.k));
      for (final row in entries) {
        final opId = row.k.substring(_kJournalOpPrefix.length);
        final raw = _decodeMap(row.v);
        if (raw == null) continue;
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
    if (box == null) return;
    final entries = _allWithKeyPrefix(box, _kJournalOpPrefix)
      ..sort((a, b) => a.k.compareTo(b.k));
    for (final row in entries) {
      final raw = _decodeMap(row.v);
      if (raw == null) continue;
      final type = (raw['type'] as String?) ?? '';
      final docId = (raw['docId'] as String?) ?? '';
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : <String, dynamic>{};
      if (type == 'update') {
        final current = Map<String, dynamic>.from(
          _decodeMap(_getByKey(box, '$_kJournalPrefix$docId')?.v) ??
              <String, dynamic>{},
        );
        data.forEach((k, v) {
          current[k] = v;
        });
        await _putMap(box, '$_kJournalPrefix$docId', current);
      } else if (type == 'delete') {
        await _removeKey(box, '$_kJournalPrefix$docId');
      }
    }
  }

  LocalJournalEntry _entryFromMap(String id, Map<String, dynamic> data) {
    double sortOrder = 0;
    final order = data['order'];
    if (order is num) {
      sortOrder = order.toDouble();
    } else if (data['createdAt'] is Timestamp) {
      sortOrder =
          (data['createdAt'] as Timestamp).millisecondsSinceEpoch.toDouble();
    } else if (data['createdAt'] is int) {
      sortOrder = (data['createdAt'] as int).toDouble();
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
        ? Map<String, dynamic>.from(
            aiRaw.map((k, v) => MapEntry(k.toString(), v)),
          )
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
}

// --- KVP (duplicate helpers for journal; keep private) ---

List<ObKv> _allWithKeyPrefix(Box<ObKv> box, String prefix) {
  final q = box.query(ObKv_.k.startsWith(prefix)).build();
  final list = q.find();
  q.close();
  return list;
}

List<String> _allKeyStringsWithPrefix(Box<ObKv> box, String prefix) {
  return _allWithKeyPrefix(box, prefix).map((e) => e.k).toList();
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
