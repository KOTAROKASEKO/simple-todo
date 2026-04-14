import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'isar/app_isar.dart';
import 'journal_local_store.dart';
import 'models/local_journal_entry.dart';

/// Clears shared app Isar (tasks + journals) on sign-out — no-op on web.
Future<void> clearJournalIsarOnLogout() => clearAppIsarOnLogout();

/// Web: journal uses Firestore only ([TodoHomePage] does not call [init]).
class JournalStore implements JournalLocalStore {
  JournalStore({required this.journalRef});

  final CollectionReference<Map<String, dynamic>> journalRef;

  Stream<void> get changes => const Stream<void>.empty();

  Future<void> init() async {}

  void dispose() {}

  List<LocalJournalEntry> getAllJournalEntries() => const [];

  Future<void> ingestAfterRemoteCreate(
    String docId,
    Map<String, dynamic> data,
  ) async {}

  Future<void> updateJournal(
    String id,
    Map<String, dynamic> updateData,
  ) async {}

  Future<void> deleteJournal(String id) async {}
}
