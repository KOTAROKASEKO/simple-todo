/// Checklist row used by the task UI and local store.
class TaskChecklistItem {
  TaskChecklistItem({required this.text, this.isDone = false});

  String text;
  bool isDone;
}

/// In-memory task for the home UI. Persisted on mobile via Isar [TaskDoc].
class LocalTask {
  LocalTask({
    this.firestoreId,
    required this.storageKey,
    required this.title,
    this.isDone = false,
    this.isRecurringDaily = false,
    this.dateKey,
    this.lastResetOn,
    this.completedOnDayKey,
    this.createdAtMillis,
    this.checklist,
    this.reminderHour,
    this.reminderMinute,
    this.remindAtMillis,
    this.reminderPending = false,
    this.doneByDate,
    this.checklistDoneByDate,
  });

  /// Set after the Firestore document exists; null while `storageKey` is a temp id.
  String? firestoreId;

  /// Isar `docKey` — Firestore id or `temp_…` while creating.
  String storageKey;

  String title;
  bool isDone;
  bool isRecurringDaily;
  String? dateKey;
  String? lastResetOn;
  String? completedOnDayKey;
  int? createdAtMillis;
  List<TaskChecklistItem>? checklist;
  int? reminderHour;
  int? reminderMinute;
  int? remindAtMillis;
  bool reminderPending;
  Map<String, bool>? doneByDate;
  Map<String, List<bool>>? checklistDoneByDate;
}
