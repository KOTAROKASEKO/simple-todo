import 'package:cloud_firestore/cloud_firestore.dart';

/// In-memory journal row (mobile reads from Isar; web uses Firestore only).
class LocalJournalEntry {
  const LocalJournalEntry({
    required this.id,
    required this.content,
    required this.category,
    required this.sortOrder,
    this.createdAtMillis,
    this.imagePaths,
    this.imagePathLegacy,
    this.aiReflection,
    required this.journalAiFeedbackRequested,
  });

  final String id;
  final String content;
  final String category;
  final double sortOrder;
  final int? createdAtMillis;
  final List<String>? imagePaths;
  final String? imagePathLegacy;
  final Map<String, dynamic>? aiReflection;
  final bool journalAiFeedbackRequested;

  /// Map shaped like Firestore data for existing journal UI helpers.
  Map<String, dynamic> toUiMap() {
    return <String, dynamic>{
      'content': content,
      'category': category,
      'order': sortOrder,
      'createdAt': createdAtMillis != null
          ? Timestamp.fromMillisecondsSinceEpoch(createdAtMillis!)
          : null,
      if (imagePaths != null && imagePaths!.isNotEmpty) 'imagePaths': imagePaths,
      if (imagePathLegacy != null && imagePathLegacy!.isNotEmpty)
        'imagePath': imagePathLegacy,
      if (aiReflection != null) 'aiReflection': aiReflection,
      'journalAiFeedbackRequested': journalAiFeedbackRequested,
    };
  }
}
