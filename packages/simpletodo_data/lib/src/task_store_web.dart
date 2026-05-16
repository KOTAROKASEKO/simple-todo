import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'isar/app_isar.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart' show TaskLocalStore, LocalTask;

/// Clears shared app Isar (tasks + journals) on sign-out — no-op on web.
Future<void> clearTaskIsarOnLogout() => clearAppIsarOnLogout();

/// Web: tasks use Firestore only ([TodoHomePage] does not call [init]).
class TaskStore implements TaskLocalStore {
  TaskStore({
    required this.userId,
    required this.tasksRef,
  });

  final String userId;
  final CollectionReference<Map<String, dynamic>> tasksRef;

  Stream<void> get changes => const Stream<void>.empty();

  Future<void> init() async {}

  void dispose() {}

  Future<String?> addTask(Map<String, dynamic> taskData) async {
    throw UnsupportedError('TaskStore.addTask is not used on web');
  }

  List<LocalTask> getAllTasks() => const [];

  String getTaskId(LocalTask task) => task.firestoreId ?? task.storageKey;

  LocalTask? getTask(String id) => null;

  Future<void> updateTask(String id, Map<String, dynamic> updateData) async {}

  Future<void> deleteTask(String id) async {}

  Map<String, dynamic> taskToMap(LocalTask task) => <String, dynamic>{};
}
