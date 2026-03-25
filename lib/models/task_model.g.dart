// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveTaskAdapter extends TypeAdapter<HiveTask> {
  @override
  final int typeId = 0;

  @override
  HiveTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveTask(
      firestoreId: fields[0] as String?,
      title: fields[1] as String,
      isDone: fields[2] as bool,
      isRecurringDaily: fields[3] as bool,
      dateKey: fields[4] as String?,
      lastResetOn: fields[5] as String?,
      createdAtMillis: fields[6] as int?,
      checklist: (fields[7] as List?)?.cast<HiveChecklistItem>(),
      reminderHour: fields[8] as int?,
      reminderMinute: fields[9] as int?,
      remindAtMillis: fields[10] as int?,
      reminderPending: fields[11] as bool,
      doneByDate: (fields[12] as Map?)?.cast<String, bool>(),
      checklistDoneByDate: (fields[13] as Map?)?.map(
        (k, v) => MapEntry(
          k.toString(),
          (v as List).map((e) => e == true).toList(),
        ),
      ),
    );
  }

  @override
  void write(BinaryWriter writer, HiveTask obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.firestoreId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isDone)
      ..writeByte(3)
      ..write(obj.isRecurringDaily)
      ..writeByte(4)
      ..write(obj.dateKey)
      ..writeByte(5)
      ..write(obj.lastResetOn)
      ..writeByte(6)
      ..write(obj.createdAtMillis)
      ..writeByte(7)
      ..write(obj.checklist)
      ..writeByte(8)
      ..write(obj.reminderHour)
      ..writeByte(9)
      ..write(obj.reminderMinute)
      ..writeByte(10)
      ..write(obj.remindAtMillis)
      ..writeByte(11)
      ..write(obj.reminderPending)
      ..writeByte(12)
      ..write(obj.doneByDate)
      ..writeByte(13)
      ..write(obj.checklistDoneByDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveChecklistItemAdapter extends TypeAdapter<HiveChecklistItem> {
  @override
  final int typeId = 1;

  @override
  HiveChecklistItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveChecklistItem(
      text: fields[0] as String,
      isDone: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveChecklistItem obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.isDone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveChecklistItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
