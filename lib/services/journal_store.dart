import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';
import 'package:simpletodo/models/journal_doc.dart';
import 'package:simpletodo/services/app_isar.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
  return out;
}

/// In-memory journal row read from [JournalDoc].
class LocalJournalEntry {
  const LocalJournalEntry({
    required this.id,
    required this.content,
    required this.category,
    required this.sortOrder,
    this.createdAtMillis,
    this.imagePaths,
    this.imagePathLegacy,
    this.aiReflection,
    required this.journalAiFeedbackRequested,
  });

  final String id;
  final String content;
  final String category;
  final double sortOrder;
  final int? createdAtMillis;
  final List<String>? imagePaths;
  final String? imagePathLegacy;
  final Map<String, dynamic>? aiReflection;
  final bool journalAiFeedbackRequested;

  /// Map shaped like Firestore data for existing journal UI helpers.
  Map<String, dynamic> toUiMap() {
    return <String, dynamic>{
      'content': content,
      'category': category,
      'order': sortOrder,
      'createdAt': createdAtMillis != null
          ? Timestamp.fromMillisecondsSinceEpoch(createdAtMillis!)
          : null,
      if (imagePaths != null && imagePaths!.isNotEmpty) 'imagePaths': imagePaths,
      if (imagePathLegacy != null && imagePathLegacy!.isNotEmpty)
        'imagePath': imagePathLegacy,
      if (aiReflection != null) 'aiReflection': aiReflection,
      'journalAiFeedbackRequested': journalAiFeedbackRequested,
    };
  }
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
class JournalStore {
  JournalStore({required this.journalRef});

  final CollectionReference<Map<String, dynamic>> journalRef;

  Isar? _isar;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSub;

  Stream<void> get changes {
    final isar = _isar;
    if (isar == null) {
      return const Stream<void>.empty();
    }
    return isar.journalDocs.where().watchLazy(fireImmediately: true);
  }

  Future<void> init() async {
    _isar = await _ensureJournalIsarOpen();

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
  }

  List<LocalJournalEntry> getAllJournalEntries() {
    final isar = _isar;
    if (isar == null) return const [];
    final docs = isar.journalDocs.where().findAllSync();
    final list = docs.map(_localJournalFromDoc).toList();
    list.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    return list;
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

    await isar.writeTxn(() async {
      await isar.journalDocs.put(row);
    });

    unawaited(
      journalRef.doc(id).update(updateData).catchError((Object e, StackTrace st) {
        debugPrint('JournalStore Firestore update failed for $id: $e');
      }),
    );
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

    unawaited(
      journalRef.doc(id).delete().catchError((Object e, StackTrace st) {
        debugPrint('JournalStore Firestore delete failed for $id: $e');
      }),
    );
  }
}
