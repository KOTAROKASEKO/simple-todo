import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar/app_isar_io.dart';
import 'isar/journal_doc.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart' show JournalLocalStore, LocalJournalEntry;

/// Clears shared app Isar (tasks + journals) on sign-out.
Future<void> clearJournalIsarOnLogout() => clearAppIsarOnLogout();

Future<Isar> _ensureJournalIsarOpen() => ensureAppIsarOpen();

JournalDoc _journalDocFromFirestore(String docId, Map<String, dynamic> data) {
  final row = JournalDoc()
    ..docKey = docId
    ..content = (data['content'] as String?) ?? ''
    ..category =
        ((data['category'] as String?) ?? 'diary').toLowerCase().trim()
    ..journalAiFeedbackRequested =
        (data['journalAiFeedbackRequested'] as bool?) ?? false;

  final orderRaw = data['order'];
  final created = data['createdAt'];
  Timestamp? createdTs;
  if (created is Timestamp) {
    createdTs = created;
  }
  if (orderRaw is num) {
    row.sortOrder = orderRaw.toDouble();
  } else if (createdTs != null) {
    row.sortOrder = createdTs.millisecondsSinceEpoch.toDouble();
  } else {
    row.sortOrder = 0;
  }

  if (createdTs != null) {
    row.createdAtMillis = createdTs.millisecondsSinceEpoch;
  } else {
    row.createdAtMillis = null;
  }

  final paths = data['imagePaths'];
  if (paths is List && paths.isNotEmpty) {
    final urls = paths.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    row.imagePathsJson = urls.isEmpty ? null : jsonEncode(urls);
  } else {
    row.imagePathsJson = null;
  }

  final legacy = data['imagePath'] as String?;
  row.imagePathLegacy =
      (legacy != null && legacy.isNotEmpty) ? legacy : null;

  final ai = data['aiReflection'];
  if (ai is Map) {
    final safe = _aiReflectionMapForJson(Map<String, dynamic>.from(
      ai.map((k, v) => MapEntry(k.toString(), v)),
    ));
    row.aiReflectionJson =
        safe.isEmpty ? null : jsonEncode(safe);
  } else {
    row.aiReflectionJson = null;
  }

  return row;
}

/// Firestore nested maps include [Timestamp] (e.g. generatedAt); [jsonEncode] cannot encode them.
Map<String, dynamic> _aiReflectionMapForJson(Map<String, dynamic> raw) {
  final out = <String, dynamic>{};
  void putStr(String key) {
    final v = raw[key];
    if (v is String && v.trim().isNotEmpty) {
      out[key] = v.trim();
    }
  }

  putStr('affirmation');
  putStr('advice');
  putStr('message');
  putStr('reflection');
  putStr('body');
  putStr('character');

  final gen = raw['generatedAt'];
  if (gen is Timestamp) {
    out['generatedAtMillis'] = gen.millisecondsSinceEpoch;
  } else if (gen is int) {
    out['generatedAtMillis'] = gen;
  }

  final via = raw['deliveredVia'];
  if (via is String && via.isNotEmpty) {
    out['deliveredVia'] = via;
  }
  final readAt = raw['readAt'];
  if (readAt is Timestamp) {
    out['readAtMillis'] = readAt.millisecondsSinceEpoch;
  } else if (readAt is int) {
    out['readAtMillis'] = readAt;
  }
  final readAtMillis = raw['readAtMillis'];
  if (readAtMillis is int) {
    out['readAtMillis'] = readAtMillis;
  }
  return out;
}

LocalJournalEntry _localJournalFromDoc(JournalDoc d) {
  List<String>? paths;
  if (d.imagePathsJson != null && d.imagePathsJson!.isNotEmpty) {
    final raw = jsonDecode(d.imagePathsJson!);
    if (raw is List) {
      paths = raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
  }
  Map<String, dynamic>? ai;
  if (d.aiReflectionJson != null && d.aiReflectionJson!.isNotEmpty) {
    final raw = jsonDecode(d.aiReflectionJson!);
    if (raw is Map) {
      ai = Map<String, dynamic>.from(raw);
    }
  }
  return LocalJournalEntry(
    id: d.docKey,
    content: d.content,
    category: d.category,
    sortOrder: d.sortOrder,
    createdAtMillis: d.createdAtMillis,
    imagePaths: paths,
    imagePathLegacy: d.imagePathLegacy,
    aiReflection: ai,
    journalAiFeedbackRequested: d.journalAiFeedbackRequested,
  );
}

/// Mobile: Isar primary; Firestore [snapshots] merges into Isar (same idea as [TaskStore]).
class JournalStore implements JournalLocalStore {
  JournalStore({required this.journalRef});

  final CollectionReference<Map<String, dynamic>> journalRef;

  Isar? _isar;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;
  bool _drainingPendingOps = false;
  final Set<String> _inFlightOpIds = <String>{};

  Stream<void> get changes {
    final isar = _isar;
    if (isar == null) {
      return const Stream<void>.empty();
    }
    return isar.journalDocs.where().watchLazy(fireImmediately: true);
  }

  Future<void> init() async {
    _isar = await _ensureJournalIsarOpen();
    await _drainPendingOps();

    await _firebaseSub?.cancel();
    _firebaseSub = journalRef
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
            if (!doc.exists) continue;
            final data = doc.data();
            if (data == null) continue;
            await _upsertFirestoreDoc(isar, doc.id, data);
            break;
          case DocumentChangeType.removed:
            final id = change.doc.id;
            final existing =
                await isar.journalDocs.filter().docKeyEqualTo(id).findFirst();
            if (existing != null) {
              await isar.journalDocs.delete(existing.id);
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
    final row = _journalDocFromFirestore(docId, data);
    final existing =
        await isar.journalDocs.filter().docKeyEqualTo(docId).findFirst();
    if (existing != null) {
      row.id = existing.id;
    }
    await isar.journalDocs.put(row);
  }

  void dispose() {
    unawaited(_firebaseSub?.cancel());
    _firebaseSub = null;
    _isar = null;
  }

  List<LocalJournalEntry> getAllJournalEntries() {
    final isar = _isar;
    if (isar == null) return const [];
    try {
      final docs = isar.journalDocs.where().findAllSync();
      final list = docs.map(_localJournalFromDoc).toList();
      list.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
      return list;
    } on IsarError {
      return const [];
    }
  }

  /// Call after a successful Firestore [DocumentReference.set] so the list updates immediately.
  Future<void> ingestAfterRemoteCreate(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await _upsertFirestoreDoc(isar, docId, data);
    });
  }

  Future<void> updateJournal(
    String id,
    Map<String, dynamic> updateData,
  ) async {
    final isar = _isar;
    if (isar == null) return;

    final row = isar.journalDocs.filter().docKeyEqualTo(id).findFirstSync();
    if (row == null) return;

    if (updateData.containsKey('order')) {
      final v = updateData['order'];
      if (v is num) {
        row.sortOrder = v.toDouble();
      }
    }
    if (updateData.containsKey('category')) {
      final c = (updateData['category'] as String?) ?? 'diary';
      row.category = c.toLowerCase();
    }
    if (updateData.containsKey('aiReflection')) {
      final raw = updateData['aiReflection'];
      if (raw is Map) {
        final safe = _aiReflectionMapForJson(
          Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))),
        );
        row.aiReflectionJson = safe.isEmpty ? null : jsonEncode(safe);
      }
    }
    if (updateData.containsKey('aiReflection.readAt')) {
      Map<String, dynamic> existing = <String, dynamic>{};
      if (row.aiReflectionJson != null && row.aiReflectionJson!.isNotEmpty) {
        final raw = jsonDecode(row.aiReflectionJson!);
        if (raw is Map) {
          existing = Map<String, dynamic>.from(raw);
        }
      }
      final readAt = updateData['aiReflection.readAt'];
      if (readAt is Timestamp) {
        existing['readAtMillis'] = readAt.millisecondsSinceEpoch;
      } else if (readAt is int) {
        existing['readAtMillis'] = readAt;
      } else {
        existing['readAtMillis'] = DateTime.now().millisecondsSinceEpoch;
      }
      final safe = _aiReflectionMapForJson(existing);
      row.aiReflectionJson = safe.isEmpty ? null : jsonEncode(safe);
    }

    await isar.writeTxn(() async {
      await isar.journalDocs.put(row);
    });

    final opId = await _enqueuePendingOp(
      type: 'update',
      docId: id,
      data: updateData,
    );
    unawaited(_sendUpdateOp(opId, id, updateData));
  }

  Future<void> deleteJournal(String id) async {
    final isar = _isar;
    if (isar == null) return;

    await isar.writeTxn(() async {
      final row =
          await isar.journalDocs.filter().docKeyEqualTo(id).findFirst();
      if (row != null) {
        await isar.journalDocs.delete(row.id);
      }
    });
    final opId = await _enqueuePendingOp(
      type: 'delete',
      docId: id,
      data: const <String, dynamic>{},
    );
    unawaited(_sendDeleteOp(opId, id));
  }

  Future<File> _pendingOpsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final safePathKey = journalRef.path.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return File('${dir.path}/journal_pending_ops_$safePathKey.json');
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
    final ops = await _loadPendingOps();
    ops.add(<String, dynamic>{
      'opId': opId,
      'type': type,
      'docId': docId,
      'data': data,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _savePendingOps(ops);
    return opId;
  }

  Future<void> _removePendingOp(String opId) async {
    final ops = await _loadPendingOps();
    ops.removeWhere((op) => (op['opId'] as String?) == opId);
    await _savePendingOps(ops);
  }

  Future<void> _sendUpdateOp(
    String opId,
    String docId,
    Map<String, dynamic> updateData,
  ) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await journalRef.doc(docId).update(updateData);
      await _removePendingOp(opId);
    } catch (e) {
      debugPrint('JournalStore Firestore update failed for $docId: $e');
    } finally {
      if (opId.isNotEmpty) _inFlightOpIds.remove(opId);
    }
  }

  Future<void> _sendDeleteOp(String opId, String docId) async {
    if (opId.isNotEmpty && !_inFlightOpIds.add(opId)) return;
    try {
      await journalRef.doc(docId).delete();
      await _removePendingOp(opId);
    } catch (e) {
      debugPrint('JournalStore Firestore delete failed for $docId: $e');
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
        if (type == 'update') {
          final row = await isar.journalDocs.filter().docKeyEqualTo(docId).findFirst();
          if (row == null) continue;
          if (data.containsKey('order')) {
            final v = data['order'];
            if (v is num) row.sortOrder = v.toDouble();
          }
          if (data.containsKey('category')) {
            final c = (data['category'] as String?) ?? 'diary';
            row.category = c.toLowerCase();
          }
          if (data.containsKey('aiReflection')) {
            final raw = data['aiReflection'];
            if (raw is Map) {
              final safe = _aiReflectionMapForJson(
                Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))),
              );
              row.aiReflectionJson = safe.isEmpty ? null : jsonEncode(safe);
            }
          }
          await isar.journalDocs.put(row);
        } else if (type == 'delete') {
          final row = await isar.journalDocs.filter().docKeyEqualTo(docId).findFirst();
          if (row != null) {
            await isar.journalDocs.delete(row.id);
          }
        }
      }
    });
  }
}
