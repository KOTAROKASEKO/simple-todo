import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/local_task.dart';

/// Platform-agnostic contract for offline-first tasks (Isar on IO, unused on web).
abstract interface class TaskLocalStore {
  String get userId;

  CollectionReference<Map<String, dynamic>> get tasksRef;

  Stream<void> get changes;

  Future<void> init();

  void dispose();

  Future<String?> addTask(Map<String, dynamic> taskData);

  List<LocalTask> getAllTasks();

  String getTaskId(LocalTask task);

  LocalTask? getTask(String id);

  Future<void> updateTask(String id, Map<String, dynamic> updateData);

  Future<void> deleteTask(String id);

  Map<String, dynamic> taskToMap(LocalTask task);
}
