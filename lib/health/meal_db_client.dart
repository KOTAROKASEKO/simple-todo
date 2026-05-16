import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:simpletodo/health/static_recipes.dart';

/// Lightweight client for [TheMealDB](https://www.themealdb.com/api.php) (no API key).
class MealSummary {
  const MealSummary({
    required this.id,
    required this.name,
    this.thumbUrl,
    this.description,
  });

  final String id;
  final String name;
  final String? thumbUrl;
  /// Short blurb for cards (optional).
  final String? description;

  /// Image for list/grid cards; uses API thumb when present, else a stable placeholder.
  String get displayThumbUrl {
    final u = thumbUrl?.trim();
    if (u != null && u.isNotEmpty) return u;
    return kRecipePlaceholderThumb(id);
  }
}

class MealDetail extends MealSummary {
  const MealDetail({
    required super.id,
    required super.name,
    super.thumbUrl,
    super.description,
    this.searchTags = const [],
    required this.ingredientLines,
    this.stepLines = const [],
  });

  /// Optional keywords (e.g. user recipes); empty for TheMealDB meals.
  final List<String> searchTags;
  final List<String> ingredientLines;
  /// Parsed cooking steps → todo checklist.
  final List<String> stepLines;
}

/// Turn TheMealDB [strInstructions] into short checklist-friendly lines.
List<String> recipeStepsFromInstructions(String? raw) {
  if (raw == null) return const [];
  final t = raw.replaceAll('\r', '\n').trim();
  if (t.isEmpty) return const [];

  var chunks = t
      .split(RegExp(r'\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (chunks.length <= 1 && chunks.isNotEmpty && chunks.first.length > 160) {
    chunks = chunks.first
        .split(RegExp(r'\.\s+'))
        .map((s) {
          var x = s.trim();
          if (x.isEmpty) return '';
          if (!x.endsWith('.')) x = '$x.';
          return x;
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  final out = <String>[];
  final stepPrefix = RegExp(
    r'^(STEP\s*)?\d+[\).\s:：－\-]+',
    caseSensitive: false,
  );
  for (var line in chunks) {
    line = line.replaceFirst(stepPrefix, '').trim();
    if (line.length < 4) continue;
    out.add(line.length > 220 ? '${line.substring(0, 217)}…' : line);
    if (out.length >= 22) break;
  }
  return out;
}

/// TheMealDB has no dedicated description; build a short line from metadata / intro.
String? mealDescriptionFromApiRow(Map<String, dynamic> row) {
  final cat = (row['strCategory'] ?? '').toString().trim();
  final area = (row['strArea'] ?? '').toString().trim();
  if (cat.isNotEmpty && area.isNotEmpty) return '$cat · $area';
  if (cat.isNotEmpty) return cat;
  if (area.isNotEmpty) return area;
  final tags = (row['strTags'] ?? '').toString().trim();
  if (tags.isNotEmpty) {
    final parts = tags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    return parts.take(4).join(' · ');
  }
  final inst = row['strInstructions']?.toString().trim();
  if (inst != null && inst.isNotEmpty) {
    var one = inst.split(RegExp(r'[\n\r]+')).first.trim();
    if (one.length > 140) one = '${one.substring(0, 137)}…';
    return one;
  }
  return null;
}

class MealDbClient {
  MealDbClient._();

  static final Uri _base = Uri.parse('https://www.themealdb.com/api/json/v1/1');

  static Future<List<MealSummary>> _remoteSearchMeals(String query) async {
    final uri = _base.replace(
      path: '${_base.path}/search.php',
      queryParameters: {'s': query},
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Recipe search failed (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final meals = decoded['meals'];
    if (meals == null) return const [];
    if (meals is! List<dynamic>) return const [];
    final out = <MealSummary>[];
    for (final row in meals) {
      if (row is! Map<String, dynamic>) continue;
      final id = row['idMeal']?.toString();
      final name = row['strMeal']?.toString();
      if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
      out.add(
        MealSummary(
          id: id,
          name: name,
          thumbUrl: row['strMealThumb']?.toString(),
        ),
      );
    }
    return out;
  }

  /// Empty query returns no TheMealDB rows (Health tab still merges Algolia + your recipes).
  static Future<List<MealSummary>> searchMeals(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      return await _remoteSearchMeals(trimmed);
    } catch (_) {
      return const [];
    }
  }

  static Future<MealDetail?> lookupMeal(String id) async {
    final uri = _base.replace(
      path: '${_base.path}/lookup.php',
      queryParameters: {'i': id},
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Recipe lookup failed (${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final meals = decoded['meals'];
    if (meals is! List<dynamic> || meals.isEmpty) return null;
    final row = meals.first;
    if (row is! Map<String, dynamic>) return null;
    final mealId = row['idMeal']?.toString();
    final name = row['strMeal']?.toString();
    if (mealId == null || mealId.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    final lines = <String>[];
    for (var i = 1; i <= 20; i++) {
      final ing = (row['strIngredient$i'] ?? '').toString().trim();
      if (ing.isEmpty) continue;
      final meas = (row['strMeasure$i'] ?? '').toString().trim();
      lines.add(meas.isEmpty ? ing : '$meas $ing');
    }
    final steps = recipeStepsFromInstructions(row['strInstructions']?.toString());
    return MealDetail(
      id: mealId,
      name: name,
      thumbUrl: row['strMealThumb']?.toString(),
      description: mealDescriptionFromApiRow(row),
      searchTags: const [],
      ingredientLines: lines,
      stepLines: steps,
    );
  }
}
