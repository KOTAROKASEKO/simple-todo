import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpletodo/health/meal_db_client.dart';

const _kPrefsKey = 'health_recipe_favorites_v1';

/// Local-only favorites for Health tab (TheMealDB / public / any recipe id).
class RecipeFavoritesStore {
  RecipeFavoritesStore._();

  static Future<List<MealSummary>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <MealSummary>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final id = e['id']?.toString() ?? '';
        final name = e['name']?.toString() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        out.add(
          MealSummary(
            id: id,
            name: name,
            thumbUrl: e['thumbUrl']?.toString(),
            description: e['description']?.toString(),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(List<MealSummary> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      items
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'name': e.name,
              if (e.thumbUrl != null && e.thumbUrl!.trim().isNotEmpty)
                'thumbUrl': e.thumbUrl,
              if (e.description != null && e.description!.trim().isNotEmpty)
                'description': e.description,
            },
          )
          .toList(),
    );
    await prefs.setString(_kPrefsKey, encoded);
  }

  /// Returns whether the recipe is a favorite **after** this call.
  static Future<bool> toggle(MealSummary s) async {
    final list = List<MealSummary>.from(await load());
    final i = list.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      list.removeAt(i);
      await _save(list);
      return false;
    }
    list.insert(
      0,
      MealSummary(
        id: s.id,
        name: s.name,
        thumbUrl: s.thumbUrl,
        description: s.description,
      ),
    );
    while (list.length > 80) {
      list.removeLast();
    }
    await _save(list);
    return true;
  }
}
