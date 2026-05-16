// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_doc.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJournalDocCollection on Isar {
  IsarCollection<JournalDoc> get journalDocs => this.collection();
}

const JournalDocSchema = CollectionSchema(
  name: r'JournalDoc',
  id: -7459543040142323447,
  properties: {
    r'aiReflectionJson': PropertySchema(
      id: 0,
      name: r'aiReflectionJson',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'content': PropertySchema(id: 2, name: r'content', type: IsarType.string),
    r'createdAtMillis': PropertySchema(
      id: 3,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'docKey': PropertySchema(id: 4, name: r'docKey', type: IsarType.string),
    r'imagePathLegacy': PropertySchema(
      id: 5,
      name: r'imagePathLegacy',
      type: IsarType.string,
    ),
    r'imagePathsJson': PropertySchema(
      id: 6,
      name: r'imagePathsJson',
      type: IsarType.string,
    ),
    r'journalAiFeedbackRequested': PropertySchema(
      id: 7,
      name: r'journalAiFeedbackRequested',
      type: IsarType.bool,
    ),
    r'sortOrder': PropertySchema(
      id: 8,
      name: r'sortOrder',
      type: IsarType.double,
    ),
  },

  estimateSize: _journalDocEstimateSize,
  serialize: _journalDocSerialize,
  deserialize: _journalDocDeserialize,
  deserializeProp: _journalDocDeserializeProp,
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
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _journalDocGetId,
  getLinks: _journalDocGetLinks,
  attach: _journalDocAttach,
  version: '3.3.2',
);

int _journalDocEstimateSize(
  JournalDoc object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.aiReflectionJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.docKey.length * 3;
  {
    final value = object.imagePathLegacy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imagePathsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _journalDocSerialize(
  JournalDoc object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.aiReflectionJson);
  writer.writeString(offsets[1], object.category);
  writer.writeString(offsets[2], object.content);
  writer.writeLong(offsets[3], object.createdAtMillis);
  writer.writeString(offsets[4], object.docKey);
  writer.writeString(offsets[5], object.imagePathLegacy);
  writer.writeString(offsets[6], object.imagePathsJson);
  writer.writeBool(offsets[7], object.journalAiFeedbackRequested);
  writer.writeDouble(offsets[8], object.sortOrder);
}

JournalDoc _journalDocDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JournalDoc();
  object.aiReflectionJson = reader.readStringOrNull(offsets[0]);
  object.category = reader.readString(offsets[1]);
  object.content = reader.readString(offsets[2]);
  object.createdAtMillis = reader.readLongOrNull(offsets[3]);
  object.docKey = reader.readString(offsets[4]);
  object.id = id;
  object.imagePathLegacy = reader.readStringOrNull(offsets[5]);
  object.imagePathsJson = reader.readStringOrNull(offsets[6]);
  object.journalAiFeedbackRequested = reader.readBool(offsets[7]);
  object.sortOrder = reader.readDouble(offsets[8]);
  return object;
}

P _journalDocDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _journalDocGetId(JournalDoc object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _journalDocGetLinks(JournalDoc object) {
  return [];
}

void _journalDocAttach(IsarCollection<dynamic> col, Id id, JournalDoc object) {
  object.id = id;
}

extension JournalDocByIndex on IsarCollection<JournalDoc> {
  Future<JournalDoc?> getByDocKey(String docKey) {
    return getByIndex(r'docKey', [docKey]);
  }

  JournalDoc? getByDocKeySync(String docKey) {
    return getByIndexSync(r'docKey', [docKey]);
  }

  Future<bool> deleteByDocKey(String docKey) {
    return deleteByIndex(r'docKey', [docKey]);
  }

  bool deleteByDocKeySync(String docKey) {
    return deleteByIndexSync(r'docKey', [docKey]);
  }

  Future<List<JournalDoc?>> getAllByDocKey(List<String> docKeyValues) {
    final values = docKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'docKey', values);
  }

  List<JournalDoc?> getAllByDocKeySync(List<String> docKeyValues) {
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

  Future<Id> putByDocKey(JournalDoc object) {
    return putByIndex(r'docKey', object);
  }

  Id putByDocKeySync(JournalDoc object, {bool saveLinks = true}) {
    return putByIndexSync(r'docKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDocKey(List<JournalDoc> objects) {
    return putAllByIndex(r'docKey', objects);
  }

  List<Id> putAllByDocKeySync(
    List<JournalDoc> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'docKey', objects, saveLinks: saveLinks);
  }
}

extension JournalDocQueryWhereSort
    on QueryBuilder<JournalDoc, JournalDoc, QWhere> {
  QueryBuilder<JournalDoc, JournalDoc, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension JournalDocQueryWhere
    on QueryBuilder<JournalDoc, JournalDoc, QWhereClause> {
  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> docKeyEqualTo(
    String docKey,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'docKey', value: [docKey]),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterWhereClause> docKeyNotEqualTo(
    String docKey,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'docKey',
                lower: [],
                upper: [docKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'docKey',
                lower: [docKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'docKey',
                lower: [docKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'docKey',
                lower: [],
                upper: [docKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension JournalDocQueryFilter
    on QueryBuilder<JournalDoc, JournalDoc, QFilterCondition> {
  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'aiReflectionJson'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'aiReflectionJson'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'aiReflectionJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'aiReflectionJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'aiReflectionJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'aiReflectionJson', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  aiReflectionJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'aiReflectionJson', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'category',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  categoryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> categoryMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAtMillis'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAtMillis'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAtMillis', value: value),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  createdAtMillisBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAtMillis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'docKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'docKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'docKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> docKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'docKey', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  docKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'docKey', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imagePathLegacy'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imagePathLegacy'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imagePathLegacy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imagePathLegacy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imagePathLegacy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imagePathLegacy', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathLegacyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imagePathLegacy', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imagePathsJson'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imagePathsJson'),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imagePathsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imagePathsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imagePathsJson', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  imagePathsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imagePathsJson', value: ''),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  journalAiFeedbackRequestedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'journalAiFeedbackRequested',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> sortOrderEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sortOrder',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition>
  sortOrderGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sortOrder',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> sortOrderLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sortOrder',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterFilterCondition> sortOrderBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }
}

extension JournalDocQueryObject
    on QueryBuilder<JournalDoc, JournalDoc, QFilterCondition> {}

extension JournalDocQueryLinks
    on QueryBuilder<JournalDoc, JournalDoc, QFilterCondition> {}

extension JournalDocQuerySortBy
    on QueryBuilder<JournalDoc, JournalDoc, QSortBy> {
  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByAiReflectionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiReflectionJson', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByAiReflectionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiReflectionJson', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByDocKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByDocKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByImagePathLegacy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathLegacy', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByImagePathLegacyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathLegacy', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortByImagePathsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByImagePathsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByJournalAiFeedbackRequested() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'journalAiFeedbackRequested', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  sortByJournalAiFeedbackRequestedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'journalAiFeedbackRequested', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension JournalDocQuerySortThenBy
    on QueryBuilder<JournalDoc, JournalDoc, QSortThenBy> {
  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByAiReflectionJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiReflectionJson', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByAiReflectionJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiReflectionJson', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByDocKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByDocKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docKey', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByImagePathLegacy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathLegacy', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByImagePathLegacyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathLegacy', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenByImagePathsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByImagePathsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByJournalAiFeedbackRequested() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'journalAiFeedbackRequested', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy>
  thenByJournalAiFeedbackRequestedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'journalAiFeedbackRequested', Sort.desc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QAfterSortBy> thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }
}

extension JournalDocQueryWhereDistinct
    on QueryBuilder<JournalDoc, JournalDoc, QDistinct> {
  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByAiReflectionJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'aiReflectionJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByDocKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByImagePathLegacy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'imagePathLegacy',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctByImagePathsJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'imagePathsJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct>
  distinctByJournalAiFeedbackRequested() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'journalAiFeedbackRequested');
    });
  }

  QueryBuilder<JournalDoc, JournalDoc, QDistinct> distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }
}

extension JournalDocQueryProperty
    on QueryBuilder<JournalDoc, JournalDoc, QQueryProperty> {
  QueryBuilder<JournalDoc, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JournalDoc, String?, QQueryOperations>
  aiReflectionJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiReflectionJson');
    });
  }

  QueryBuilder<JournalDoc, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<JournalDoc, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<JournalDoc, int?, QQueryOperations> createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<JournalDoc, String, QQueryOperations> docKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docKey');
    });
  }

  QueryBuilder<JournalDoc, String?, QQueryOperations>
  imagePathLegacyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePathLegacy');
    });
  }

  QueryBuilder<JournalDoc, String?, QQueryOperations> imagePathsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePathsJson');
    });
  }

  QueryBuilder<JournalDoc, bool, QQueryOperations>
  journalAiFeedbackRequestedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'journalAiFeedbackRequested');
    });
  }

  QueryBuilder<JournalDoc, double, QQueryOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }
}
