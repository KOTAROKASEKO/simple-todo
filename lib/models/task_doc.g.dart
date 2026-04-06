// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_doc.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTaskDocCollection on Isar {
  IsarCollection<TaskDoc> get taskDocs => this.collection();
}

const TaskDocSchema = CollectionSchema(
  name: r'TaskDoc',
  id: 5213493805080020794,
  properties: {
    r'checklist': PropertySchema(
      id: 0,
      name: r'checklist',
      type: IsarType.objectList,
      target: r'TaskCheckItem',
    ),
    r'checklistDoneByDateJson': PropertySchema(
      id: 1,
      name: r'checklistDoneByDateJson',
      type: IsarType.string,
    ),
    r'completedOnDayKey': PropertySchema(
      id: 2,
      name: r'completedOnDayKey',
      type: IsarType.string,
    ),
    r'createdAtMillis': PropertySchema(
      id: 3,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'dateKey': PropertySchema(
      id: 4,
      name: r'dateKey',
      type: IsarType.string,
    ),
    r'docKey': PropertySchema(
      id: 5,
      name: r'docKey',
      type: IsarType.string,
    ),
    r'doneByDateJson': PropertySchema(
      id: 6,
      name: r'doneByDateJson',
      type: IsarType.string,
    ),
    r'isDone': PropertySchema(
      id: 7,
      name: r'isDone',
      type: IsarType.bool,
    ),
    r'isRecurringDaily': PropertySchema(
      id: 8,
      name: r'isRecurringDaily',
      type: IsarType.bool,
    ),
    r'lastResetOn': PropertySchema(
      id: 9,
      name: r'lastResetOn',
      type: IsarType.string,
    ),
    r'remindAtMillis': PropertySchema(
      id: 10,
      name: r'remindAtMillis',
      type: IsarType.long,
    ),
    r'reminderHour': PropertySchema(
      id: 11,
      name: r'reminderHour',
      type: IsarType.long,
    ),
    r'reminderMinute': PropertySchema(
      id: 12,
      name: r'reminderMinute',
      type: IsarType.long,
    ),
    r'reminderPending': PropertySchema(
      id: 13,
      name: r'reminderPending',
      type: IsarType.bool,
    ),
    r'title': PropertySchema(
      id: 14,
      name: r'title',
      type: IsarType.string,
    )
  },
  estimateSize: _taskDocEstimateSize,
  serialize: _taskDocSerialize,
  deserialize: _taskDocDeserialize,
  deserializeProp: _taskDocDeserializeProp,
  idName: r'id',
  indexes: {
    r'docKey': IndexSchema(
      id: -3032574839672173654,
      name: r'docKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'docKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {r'TaskCheckItem': TaskCheckItemSchema},
  getId: _taskDocGetId,
  getLinks: _taskDocGetLinks,
  attach: _taskDocAttach,
  version: '3.1.0+1',
);

int _taskDocEstimateSize(
  TaskDoc object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final list = object.checklist;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        final offsets = allOffsets[TaskCheckItem]!;
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount +=
              TaskCheckItemSchema.estimateSize(value, offsets, allOffsets);
        }
      }
    }
  }
  {
    final value = object.checklistDoneByDateJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedOnDayKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.dateKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.docKey.length * 3;
  {
    final value = object.doneByDateJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastResetOn;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _taskDocSerialize(
  TaskDoc object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObjectList<TaskCheckItem>(
    offsets[0],
    allOffsets,
    TaskCheckItemSchema.serialize,
    object.checklist,
  );
  writer.writeString(offsets[1], object.checklistDoneByDateJson);
  writer.writeString(offsets[2], object.completedOnDayKey);
  writer.writeLong(offsets[3], object.createdAtMillis);
  writer.writeString(offsets[4], object.dateKey);
  writer.writeString(offsets[5], object.docKey);
  writer.writeString(offsets[6], object.doneByDateJson);
  writer.writeBool(offsets[7], object.isDone);
  writer.writeBool(offsets[8], object.isRecurringDaily);
  writer.writeString(offsets[9], object.lastResetOn);
  writer.writeLong(offsets[10], object.remindAtMillis);
  writer.writeLong(offsets[11], object.reminderHour);
  writer.writeLong(offsets[12], object.reminderMinute);
  writer.writeBool(offsets[13], object.reminderPending);
  writer.writeString(offsets[14], object.title);
}

TaskDoc _taskDocDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TaskDoc();
  object.checklist = reader.readObjectList<TaskCheckItem>(
    offsets[0],
    TaskCheckItemSchema.deserialize,
    allOffsets,
    TaskCheckItem(),
  );
  object.checklistDoneByDateJson = reader.readStringOrNull(offsets[1]);
  object.completedOnDayKey = reader.readStringOrNull(offsets[2]);
  object.createdAtMillis = reader.readLongOrNull(offsets[3]);
  object.dateKey = reader.readStringOrNull(offsets[4]);
  object.docKey = reader.readString(offsets[5]);
  object.doneByDateJson = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.isDone = reader.readBool(offsets[7]);
  object.isRecurringDaily = reader.readBool(offsets[8]);
  object.lastResetOn = reader.readStringOrNull(offsets[9]);
  object.remindAtMillis = reader.readLongOrNull(offsets[10]);
  object.reminderHour = reader.readLongOrNull(offsets[11]);
  object.reminderMinute = reader.readLongOrNull(offsets[12]);
  object.reminderPending = reader.readBool(offsets[13]);
  object.title = reader.readString(offsets[14]);
  return object;
}

P _taskDocDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectList<TaskCheckItem>(
        offset,
        TaskCheckItemSchema.deserialize,
        allOffsets,
        TaskCheckItem(),
      )) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _taskDocGetId(TaskDoc object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _taskDocGetLinks(TaskDoc object) {
  return [];
}

void _taskDocAttach(IsarCollection<dynamic> col, Id id, TaskDoc object) {
  object.id = id;
}

extension TaskDocByIndex on IsarCollection<TaskDoc> {
  Future<TaskDoc?> getByDocKey(String docKey) {
    return getByIndex(r'docKey', [docKey]);
  }

  TaskDoc? getByDocKeySync(String docKey) {
    return getByIndexSync(r'docKey', [docKey]);
  }

  Future<bool> deleteByDocKey(String docKey) {
    return deleteByIndex(r'docKey', [docKey]);
  }

  bool deleteByDocKeySync(String docKey) {
    return deleteByIndexSync(r'docKey', [docKey]);
  }

  Future<List<TaskDoc?>> getAllByDocKey(List<String> docKeyValues) {
    final values = docKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'docKey', values);
  }

  List<TaskDoc?> getAllByDocKeySync(List<String> docKeyValues) {
    final values = docKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'docKey', values);
  }

  Future<int> deleteAllByDocKey(List<String> docKeyValues) {
    final values = docKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'docKey', values);
  }

  int deleteAllByDocKeySync(List<String> docKeyValues) {
    final values = docKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'docKey', values);
  }

  Future<Id> putByDocKey(TaskDoc object) {
    return putByIndex(r'docKey', object);
  }

  Id putByDocKeySync(TaskDoc object, {bool saveLinks = true}) {
    return putByIndexSync(r'docKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDocKey(List<TaskDoc> objects) {
    return putAllByIndex(r'docKey', objects);
  }

  List<Id> putAllByDocKeySync(List<TaskDoc> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'docKey', objects, saveLinks: saveLinks);
  }
}

extension TaskDocQueryWhereSort on QueryBuilder<TaskDoc, TaskDoc, QWhere> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TaskDocQueryWhere on QueryBuilder<TaskDoc, TaskDoc, QWhereClause> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> docKeyEqualTo(
      String docKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'docKey',
        value: [docKey],
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterWhereClause> docKeyNotEqualTo(
      String docKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docKey',
              lower: [],
              upper: [docKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docKey',
              lower: [docKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docKey',
              lower: [docKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docKey',
              lower: [],
              upper: [docKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TaskDocQueryFilter
    on QueryBuilder<TaskDoc, TaskDoc, QFilterCondition> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checklist',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checklist',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'checklist',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checklistDoneByDateJson',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checklistDoneByDateJson',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checklistDoneByDateJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'checklistDoneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'checklistDoneByDateJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checklistDoneByDateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      checklistDoneByDateJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'checklistDoneByDateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedOnDayKey',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedOnDayKey',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedOnDayKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedOnDayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedOnDayKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedOnDayKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      completedOnDayKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedOnDayKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      createdAtMillisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAtMillis',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      createdAtMillisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAtMillis',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> createdAtMillisEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      createdAtMillisGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> createdAtMillisLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> createdAtMillisBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dateKey',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dateKey',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dateKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> dateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'docKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'docKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'docKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> docKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'docKey',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'doneByDateJson',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      doneByDateJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'doneByDateJson',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      doneByDateJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'doneByDateJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      doneByDateJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'doneByDateJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> doneByDateJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'doneByDateJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      doneByDateJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'doneByDateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      doneByDateJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'doneByDateJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> isDoneEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDone',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> isRecurringDailyEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRecurringDaily',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastResetOn',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastResetOn',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastResetOn',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastResetOn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastResetOn',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> lastResetOnIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastResetOn',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      lastResetOnIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastResetOn',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> remindAtMillisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remindAtMillis',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      remindAtMillisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remindAtMillis',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> remindAtMillisEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remindAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      remindAtMillisGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remindAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> remindAtMillisLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remindAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> remindAtMillisBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remindAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderHourIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reminderHour',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      reminderHourIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reminderHour',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderHourEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reminderHour',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderHourGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reminderHour',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderHourLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reminderHour',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderHourBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reminderHour',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderMinuteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reminderMinute',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      reminderMinuteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reminderMinute',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderMinuteEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reminderMinute',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition>
      reminderMinuteGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reminderMinute',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderMinuteLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reminderMinute',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderMinuteBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reminderMinute',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> reminderPendingEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reminderPending',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }
}

extension TaskDocQueryObject
    on QueryBuilder<TaskDoc, TaskDoc, QFilterCondition> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterFilterCondition> checklistElement(
      FilterQuery<TaskCheckItem> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'checklist');
    });
  }
}

extension TaskDocQueryLinks
    on QueryBuilder<TaskDoc, TaskDoc, QFilterCondition> {}

extension TaskDocQuerySortBy on QueryBuilder<TaskDoc, TaskDoc, QSortBy> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByChecklistDoneByDateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistDoneByDateJson', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy>
      sortByChecklistDoneByDateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistDoneByDateJson', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByCompletedOnDayKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedOnDayKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByCompletedOnDayKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedOnDayKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDocKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDocKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDoneByDateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'doneByDateJson', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByDoneByDateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'doneByDateJson', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByIsDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByIsRecurringDaily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurringDaily', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByIsRecurringDailyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurringDaily', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByLastResetOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastResetOn', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByLastResetOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastResetOn', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByRemindAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindAtMillis', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByRemindAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindAtMillis', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderHour', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderHourDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderHour', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderMinute', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderMinuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderMinute', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPending', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByReminderPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPending', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension TaskDocQuerySortThenBy
    on QueryBuilder<TaskDoc, TaskDoc, QSortThenBy> {
  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByChecklistDoneByDateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistDoneByDateJson', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy>
      thenByChecklistDoneByDateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistDoneByDateJson', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByCompletedOnDayKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedOnDayKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByCompletedOnDayKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedOnDayKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDocKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDocKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDoneByDateJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'doneByDateJson', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByDoneByDateJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'doneByDateJson', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByIsDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByIsRecurringDaily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurringDaily', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByIsRecurringDailyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecurringDaily', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByLastResetOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastResetOn', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByLastResetOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastResetOn', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByRemindAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindAtMillis', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByRemindAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindAtMillis', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderHour', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderHourDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderHour', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderMinute', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderMinuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderMinute', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPending', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByReminderPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPending', Sort.desc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension TaskDocQueryWhereDistinct
    on QueryBuilder<TaskDoc, TaskDoc, QDistinct> {
  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByChecklistDoneByDateJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checklistDoneByDateJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByCompletedOnDayKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedOnDayKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByDateKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByDocKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByDoneByDateJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'doneByDateJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDone');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByIsRecurringDaily() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRecurringDaily');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByLastResetOn(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastResetOn', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByRemindAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remindAtMillis');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByReminderHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reminderHour');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByReminderMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reminderMinute');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByReminderPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reminderPending');
    });
  }

  QueryBuilder<TaskDoc, TaskDoc, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension TaskDocQueryProperty
    on QueryBuilder<TaskDoc, TaskDoc, QQueryProperty> {
  QueryBuilder<TaskDoc, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TaskDoc, List<TaskCheckItem>?, QQueryOperations>
      checklistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checklist');
    });
  }

  QueryBuilder<TaskDoc, String?, QQueryOperations>
      checklistDoneByDateJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checklistDoneByDateJson');
    });
  }

  QueryBuilder<TaskDoc, String?, QQueryOperations> completedOnDayKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedOnDayKey');
    });
  }

  QueryBuilder<TaskDoc, int?, QQueryOperations> createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<TaskDoc, String?, QQueryOperations> dateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateKey');
    });
  }

  QueryBuilder<TaskDoc, String, QQueryOperations> docKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docKey');
    });
  }

  QueryBuilder<TaskDoc, String?, QQueryOperations> doneByDateJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'doneByDateJson');
    });
  }

  QueryBuilder<TaskDoc, bool, QQueryOperations> isDoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDone');
    });
  }

  QueryBuilder<TaskDoc, bool, QQueryOperations> isRecurringDailyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRecurringDaily');
    });
  }

  QueryBuilder<TaskDoc, String?, QQueryOperations> lastResetOnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastResetOn');
    });
  }

  QueryBuilder<TaskDoc, int?, QQueryOperations> remindAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remindAtMillis');
    });
  }

  QueryBuilder<TaskDoc, int?, QQueryOperations> reminderHourProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reminderHour');
    });
  }

  QueryBuilder<TaskDoc, int?, QQueryOperations> reminderMinuteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reminderMinute');
    });
  }

  QueryBuilder<TaskDoc, bool, QQueryOperations> reminderPendingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reminderPending');
    });
  }

  QueryBuilder<TaskDoc, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const TaskCheckItemSchema = Schema(
  name: r'TaskCheckItem',
  id: -6839630819774639836,
  properties: {
    r'isDone': PropertySchema(
      id: 0,
      name: r'isDone',
      type: IsarType.bool,
    ),
    r'text': PropertySchema(
      id: 1,
      name: r'text',
      type: IsarType.string,
    )
  },
  estimateSize: _taskCheckItemEstimateSize,
  serialize: _taskCheckItemSerialize,
  deserialize: _taskCheckItemDeserialize,
  deserializeProp: _taskCheckItemDeserializeProp,
);

int _taskCheckItemEstimateSize(
  TaskCheckItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.text.length * 3;
  return bytesCount;
}

void _taskCheckItemSerialize(
  TaskCheckItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.isDone);
  writer.writeString(offsets[1], object.text);
}

TaskCheckItem _taskCheckItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TaskCheckItem();
  object.isDone = reader.readBool(offsets[0]);
  object.text = reader.readString(offsets[1]);
  return object;
}

P _taskCheckItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension TaskCheckItemQueryFilter
    on QueryBuilder<TaskCheckItem, TaskCheckItem, QFilterCondition> {
  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      isDoneEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDone',
        value: value,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition> textEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition> textBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'text',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition> textMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<TaskCheckItem, TaskCheckItem, QAfterFilterCondition>
      textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }
}

extension TaskCheckItemQueryObject
    on QueryBuilder<TaskCheckItem, TaskCheckItem, QFilterCondition> {}
