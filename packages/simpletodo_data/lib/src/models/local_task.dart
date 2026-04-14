/// Checklist row used by the task UI and local store.
class TaskChecklistItem {
  TaskChecklistItem({required this.text, this.isDone = false});

  String text;
  bool isDone;
}

/// In-memory task for the home UI. On IO, mirrored in Isar by [TaskStore].
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
    this.reminderSuperImportant = false,
    this.doneByDate,
    this.checklistDoneByDate,
    this.recurringStreakRewardDay = 1,
    this.recurringStreakLastPaidDayKey,
    this.lastTaskRewardDayKey,
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
  bool reminderSuperImportant;
  Map<String, bool>? doneByDate;
  Map<String, List<bool>>? checklistDoneByDate;

  int recurringStreakRewardDay;
  String? recurringStreakLastPaidDayKey;
  String? lastTaskRewardDayKey;
}
