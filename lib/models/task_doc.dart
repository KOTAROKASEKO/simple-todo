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

  String? doneByDateJson;
  String? checklistDoneByDateJson;
}

@embedded
class TaskCheckItem {
  late String text;
  late bool isDone;
}
