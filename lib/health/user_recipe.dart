import 'package:simpletodo/health/static_recipes.dart';

/// User-created recipe; persisted under `todo/{uid}/user_recipes/{id}` when saved.
class UserRecipe {
  UserRecipe({
    required this.id,
    required this.name,
    this.thumbUrl,
    this.description,
    required this.ingredientLines,
    required this.stepLines,
    this.isPublic = false,
    List<String>? searchTags,
  }) : searchTags = List<String>.from(searchTags ?? const []);

  final String id;
  final String name;
  final String? thumbUrl;
  final String? description;
  final List<String> ingredientLines;
  final List<String> stepLines;
  /// When true, this recipe is merged into the Health tab search/browse grid.
  final bool isPublic;
  /// Normalized keywords for search (stored in Firestore for Algolia sync later).
  final List<String> searchTags;

  String get displayThumbUrl {
    final u = thumbUrl?.trim();
    if (u != null && u.isNotEmpty) return u;
    return kRecipePlaceholderThumb(id);
  }

  /// One tag per line → lowercase, deduped, max 24 × 40 chars. Leading `#` on a line is stripped.
  static List<String> normalizeSearchTags(String raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      var t = line.trim().toLowerCase();
      if (t.startsWith('#')) t = t.substring(1).trim();
      if (t.isEmpty) continue;
      if (t.length > 40) t = t.substring(0, 40);
      if (seen.add(t)) out.add(t);
      if (out.length >= 24) break;
    }
    return out;
  }

  /// Fields written to Firestore (timestamps added by caller).
  Map<String, dynamic> toFirestoreFields() {
    return <String, dynamic>{
      'name': name,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'ingredientLines': ingredientLines,
      'stepLines': stepLines,
      'isPublic': isPublic,
      'searchTags': searchTags,
      if (thumbUrl != null && thumbUrl!.trim().isNotEmpty) 'thumbUrl': thumbUrl!.trim(),
    };
  }

  factory UserRecipe.fromFirestore(String docId, Map<String, dynamic> d) {
    return UserRecipe(
      id: docId,
      name: (d['name'] as String?)?.trim() ?? '',
      thumbUrl: (d['thumbUrl'] as String?)?.trim(),
      description: (d['description'] as String?)?.trim(),
      ingredientLines: _stringList(d['ingredientLines']),
      stepLines: _stringList(d['stepLines']),
      isPublic: (d['isPublic'] as bool?) ?? false,
      searchTags: _stringList(d['searchTags']),
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}
