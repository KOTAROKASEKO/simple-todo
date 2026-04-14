import 'package:isar/isar.dart';

part 'task_doc.g.dart';

@collection
class TaskDoc {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String docKey;

  late String title;
  late bool isDone;
  late bool isRecurringDaily;

  String? dateKey;
  String? lastResetOn;
  /// One-time tasks: calendar day (YYYY-MM-DD) when the user marked done.
  String? completedOnDayKey;
  int? createdAtMillis;

  List<TaskCheckItem>? checklist;

  int? reminderHour;
  int? reminderMinute;
  int? remindAtMillis;

  late bool reminderPending;

  /// Local notification uses an alarm-style channel when true (Android).
  bool reminderSuperImportant = false;

  String? doneByDateJson;
  String? checklistDoneByDateJson;

  /// Next recurring daily streak tier (1–7) for coin payout.
  int recurringStreakRewardDay = 1;

  /// Last calendar day (yyyy-MM-dd) when recurring streak coins were paid.
  String? recurringStreakLastPaidDayKey;

  /// Last day task completion granted coins (prevents same-day double rewards).
  String? lastTaskRewardDayKey;
}

@embedded
class TaskCheckItem {
  late String text;
  late bool isDone;
}
