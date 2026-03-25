import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class HiveTask extends HiveObject {
  HiveTask({
    this.firestoreId,
    required this.title,
    this.isDone = false,
    this.isRecurringDaily = false,
    this.dateKey,
    this.lastResetOn,
    this.createdAtMillis,
    this.checklist,
    this.reminderHour,
    this.reminderMinute,
    this.remindAtMillis,
    this.reminderPending = false,
    this.doneByDate,
    this.checklistDoneByDate,
  });

  @HiveField(0)
  String? firestoreId;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isDone;

  @HiveField(3)
  bool isRecurringDaily;

  @HiveField(4)
  String? dateKey;

  @HiveField(5)
  String? lastResetOn;

  @HiveField(6)
  int? createdAtMillis;

  @HiveField(7)
  List<HiveChecklistItem>? checklist;

  @HiveField(8)
  int? reminderHour;

  @HiveField(9)
  int? reminderMinute;

  @HiveField(10)
  int? remindAtMillis;

  @HiveField(11)
  bool reminderPending;

  @HiveField(12)
  Map<String, bool>? doneByDate;

  /// Per-day checklist completion for recurring daily tasks (parallel to [checklist]).
  @HiveField(13)
  Map<String, List<bool>>? checklistDoneByDate;

  String get id => firestoreId ?? key?.toString() ?? '';
}

@HiveType(typeId: 1)
class HiveChecklistItem {
  HiveChecklistItem({required this.text, this.isDone = false});

  @HiveField(0)
  String text;

  @HiveField(1)
  bool isDone;
}
