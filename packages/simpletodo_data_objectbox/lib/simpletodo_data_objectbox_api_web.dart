import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart';

// Web does not use ObjectBox; the app never instantiates these when kIsWeb.

class TaskStore implements TaskLocalStore {
  TaskStore({required this.userId, required this.tasksRef});

  @override
  final String userId;

  @override
  final CollectionReference<Map<String, dynamic>> tasksRef;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<String?> addTask(Map<String, dynamic> taskData) async => null;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  void dispose() {}

  @override
  List<LocalTask> getAllTasks() => const [];

  @override
  LocalTask? getTask(String id) => null;

  @override
  String getTaskId(LocalTask task) => '';

  @override
  Future<void> init() async {}

  @override
  Map<String, dynamic> taskToMap(LocalTask task) => const {};

  @override
  Future<void> updateTask(String id, Map<String, dynamic> updateData) async {}
}

class JournalStore implements JournalLocalStore {
  JournalStore({required this.journalRef});

  @override
  final CollectionReference<Map<String, dynamic>> journalRef;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> deleteJournal(String id) async {}

  @override
  void dispose() {}

  @override
  List<LocalJournalEntry> getAllJournalEntries() => const [];

  @override
  Future<void> ingestAfterRemoteCreate(
    String docId,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> init() async {}

  @override
  Future<void> updateJournal(String id, Map<String, dynamic> updateData) async {}
}

Future<void> clearAppObjectBoxOnLogout() async {}
