import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/local_journal_entry.dart';

/// Platform-agnostic contract for offline-first journal (Isar on IO, unused on web).
abstract interface class JournalLocalStore {
  CollectionReference<Map<String, dynamic>> get journalRef;

  Stream<void> get changes;

  Future<void> init();

  void dispose();

  List<LocalJournalEntry> getAllJournalEntries();

  Future<void> ingestAfterRemoteCreate(String docId, Map<String, dynamic> data);

  Future<void> updateJournal(String id, Map<String, dynamic> updateData);

  Future<void> deleteJournal(String id);
}
