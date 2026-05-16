import 'dart:convert';

import 'package:http/http.dart' as http;

/// Search-only credentials (Algolia: restrict this key to index `public_recipes`, ACL search).
const kAlgoliaPublicRecipesApplicationId = 'SAGT02VVWJ';
const kAlgoliaPublicRecipesSearchApiKey =
    '6fcff92b2b6816dd257afe9af934a149';
const kAlgoliaPublicRecipesIndexName = 'public_recipes';

/// One hit from [searchPublicRecipesIndex] (mirrors Cloud Function–indexed fields).
class AlgoliaPublicRecipeHit {
  const AlgoliaPublicRecipeHit({
    required this.objectID,
    required this.ownerUid,
    required this.recipeId,
    required this.name,
    this.thumbUrl,
    this.description,
  });

  final String objectID;
  final String ownerUid;
  final String recipeId;
  final String name;
  final String? thumbUrl;
  final String? description;
}

/// Calls Algolia [Search API](https://www.algolia.com/doc/rest-api/search/search-single-index) from the app.
class AlgoliaPublicRecipesClient {
  AlgoliaPublicRecipesClient._();

  static final _client = http.Client();

  static Uri _queryUri(String indexName) {
    final enc = Uri.encodeComponent(indexName);
    return Uri.parse(
      'https://$kAlgoliaPublicRecipesApplicationId-dsn.algolia.net/1/indexes/$enc/query',
    );
  }

  /// Returns parsed hits, or empty list on network / API error.
  static Future<List<AlgoliaPublicRecipeHit>> searchPublicRecipesIndex(
    String queryRaw, {
    int hitsPerPage = 24,
  }) async {
    final q = queryRaw.trim();
    final body = jsonEncode(<String, dynamic>{
      'query': q,
      'hitsPerPage': hitsPerPage.clamp(1, 50),
    });
    try {
      final res = await _client
          .post(
            _queryUri(kAlgoliaPublicRecipesIndexName),
            headers: <String, String>{
              'X-Algolia-Application-Id': kAlgoliaPublicRecipesApplicationId,
              'X-Algolia-API-Key': kAlgoliaPublicRecipesSearchApiKey,
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final hits = decoded['hits'];
      if (hits is! List) return const [];
      final out = <AlgoliaPublicRecipeHit>[];
      for (final raw in hits) {
        if (raw is! Map) continue;
        final hit = Map<String, dynamic>.from(raw);
        final objectID = hit['objectID']?.toString() ?? '';
        final ownerUid = hit['ownerUid']?.toString() ?? '';
        final recipeId = hit['recipeId']?.toString() ?? '';
        final name = hit['name']?.toString().trim() ?? '';
        if (objectID.isEmpty || name.isEmpty) continue;
        final thumb = hit['thumbUrl']?.toString().trim();
        final desc = hit['description']?.toString().trim();
        out.add(
          AlgoliaPublicRecipeHit(
            objectID: objectID,
            ownerUid: ownerUid,
            recipeId: recipeId,
            name: name,
            thumbUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
            description: (desc != null && desc.isNotEmpty) ? desc : null,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
