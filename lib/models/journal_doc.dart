import 'package:isar/isar.dart';

part 'journal_doc.g.dart';

@collection
class JournalDoc {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String docKey;

  late String content;
  late String category;
  late double sortOrder;
  int? createdAtMillis;

  /// JSON array of image URLs (Firestore `imagePaths`).
  String? imagePathsJson;

  /// Legacy single image field.
  String? imagePathLegacy;

  /// JSON object for `aiReflection`.
  String? aiReflectionJson;

  late bool journalAiFeedbackRequested;
}
