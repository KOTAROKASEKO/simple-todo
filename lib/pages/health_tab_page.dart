import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpletodo/health/algolia_public_recipes_client.dart';
import 'package:simpletodo/health/meal_db_client.dart';
import 'package:simpletodo/health/recipe_favorites_store.dart';
import 'package:simpletodo/health/user_recipe.dart';
import 'package:simpletodo/pages/create_user_recipe_page.dart';

/// Prototype: recipe search (TheMealDB) and add meal + ingredients to parent state.
class HealthTabPage extends StatefulWidget {
  const HealthTabPage({
    super.key,
    required this.customRecipes,
    required this.onPersistUserRecipe,
    required this.onDeleteUserRecipe,
    required this.onAddRecipeToTodoAndBag,
  });

  final List<UserRecipe> customRecipes;
  final Future<void> Function(UserRecipe recipe, {required bool isNew})
      onPersistUserRecipe;
  final Future<void> Function(String recipeId) onDeleteUserRecipe;
  final Future<void> Function(
    String recipeTitle,
    List<String> selectedIngredientsForBag,
    List<String> checklistSteps,
  ) onAddRecipeToTodoAndBag;

  @override
  State<HealthTabPage> createState() => _HealthTabPageState();
}

class _HealthTabPageState extends State<HealthTabPage> {
  final _searchController = TextEditingController();
  /// Last successful API/static merge (without public user recipes).
  List<MealSummary> _apiResults = const [];
  /// Last Algolia hits from [searchPublicRecipes] (empty if unsigned-in / error).
  List<MealSummary> _publicAlgoliaResults = const [];
  List<MealSummary> _results = const [];
  List<MealSummary> _favorites = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runSearch());
      if (mounted) unawaited(_loadFavorites());
    });
  }

  Future<void> _loadFavorites() async {
    final list = await RecipeFavoritesStore.load();
    if (!mounted) return;
    setState(() => _favorites = list);
  }

  MealSummary _summaryFromDetail(MealDetail d) {
    return MealSummary(
      id: d.id,
      name: d.name,
      thumbUrl: d.thumbUrl,
      description: d.description,
    );
  }

  Widget _recipeSearchResultTile({
    required MealSummary m,
    required double cardW,
    required double cardH,
    required ColorScheme scheme,
  }) {
    final desc = m.description?.trim();
    return SizedBox(
      width: cardW,
      height: cardH,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_openRecipe(m)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 72,
                child: _RecipeGridThumb(
                  imageUrl: m.displayThumbUrl,
                  scheme: scheme,
                ),
              ),
              Expanded(
                flex: 28,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (desc != null && desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _horizontalRecipeCarousel({
    required List<MealSummary> items,
    required double cardW,
    required double cardH,
    required ColorScheme scheme,
  }) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        return _recipeSearchResultTile(
          m: items[index],
          cardW: cardW,
          cardH: cardH,
          scheme: scheme,
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant HealthTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_searching &&
        !identical(oldWidget.customRecipes, widget.customRecipes)) {
      setState(() {
        _results = _mergeLocalAndPublicInto(
          _apiResults,
          _searchController.text,
          _publicAlgoliaResults,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _publicUserRecipeMatchesQuery(UserRecipe r, String queryTrimmed) {
    final q = queryTrimmed.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (r.name.toLowerCase().contains(q)) return true;
    final rd = r.description?.toLowerCase();
    if (rd != null && rd.contains(q)) return true;
    for (final line in r.ingredientLines) {
      if (line.toLowerCase().contains(q)) return true;
    }
    for (final line in r.stepLines) {
      if (line.toLowerCase().contains(q)) return true;
    }
    for (final t in r.searchTags) {
      if (t.contains(q)) return true;
    }
    return false;
  }

  List<MealSummary> _mergeLocalAndPublicInto(
    List<MealSummary> base,
    String queryTrimmed,
    List<MealSummary> fromAlgolia,
  ) {
    final seen = {for (final s in base) s.id};
    final out = [...base];
    for (final s in fromAlgolia) {
      if (seen.add(s.id)) out.add(s);
    }
    for (final r in widget.customRecipes) {
      if (!r.isPublic) continue;
      if (!_publicUserRecipeMatchesQuery(r, queryTrimmed)) continue;
      if (!seen.add(r.id)) continue;
      out.add(
        MealSummary(
          id: r.id,
          name: r.name,
          thumbUrl: r.thumbUrl,
          description: r.description,
        ),
      );
    }
    return out;
  }

  Future<List<MealSummary>> _searchPublicRecipesViaAlgolia(String queryRaw) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const [];
    try {
      final hits =
          await AlgoliaPublicRecipesClient.searchPublicRecipesIndex(queryRaw);
      final uid = user.uid;
      final ownIds = {for (final r in widget.customRecipes) r.id};
      final out = <MealSummary>[];
      for (final h in hits) {
        if (h.ownerUid == uid && ownIds.contains(h.recipeId)) continue;
        out.add(
          MealSummary(
            id: 'pub:${h.objectID}',
            name: h.name,
            thumbUrl: h.thumbUrl,
            description: h.description,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  List<String> _stringListField(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<MealDetail?> _fetchPublicRecipeDetail(String publicDocId) async {
    final snap = await FirebaseFirestore.instance
        .collection('public_recipes')
        .doc(publicDocId)
        .get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    final name = (d['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    return MealDetail(
      id: 'pub:$publicDocId',
      name: name,
      thumbUrl: (d['thumbUrl'] as String?)?.trim(),
      description: (d['description'] as String?)?.trim(),
      searchTags: _stringListField(d['searchTags']),
      ingredientLines: _stringListField(d['ingredientLines']),
      stepLines: _stringListField(d['stepLines']),
    );
  }

  MealDetail? _mealDetailForUserRecipeId(String id) {
    for (final r in widget.customRecipes) {
      if (r.id == id) {
        return MealDetail(
          id: r.id,
          name: r.name,
          thumbUrl: r.thumbUrl,
          description: r.description,
          searchTags: List<String>.from(r.searchTags),
          ingredientLines: List<String>.from(r.ingredientLines),
          stepLines: List<String>.from(r.stepLines),
        );
      }
    }
    return null;
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _results = const [];
    });
    try {
      final queryText = _searchController.text;
      final list = await MealDbClient.searchMeals(queryText);
      final fromAlgolia = await _searchPublicRecipesViaAlgolia(queryText);
      if (!mounted) return;
      setState(() {
        _apiResults = list;
        _publicAlgoliaResults = fromAlgolia;
        _results = _mergeLocalAndPublicInto(
          list,
          queryText,
          fromAlgolia,
        );
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _openRecipe(MealSummary summary) async {
    MealDetail? detail;
    if (summary.id.startsWith('pub:')) {
      final docId = summary.id.substring(4);
      detail = await _fetchPublicRecipeDetail(docId);
    } else {
      detail = _mealDetailForUserRecipeId(summary.id);
      if (detail == null) {
        try {
          detail = await MealDbClient.lookupMeal(summary.id);
        } catch (_) {
          detail = null;
        }
      }
    }
    if (!mounted) return;
    final d = detail ??
        MealDetail(
          id: summary.id,
          name: summary.name,
          thumbUrl: summary.thumbUrl,
          description: summary.description,
          searchTags: const [],
          ingredientLines: const [],
          stepLines: const [],
        );
    final showEdit = d.id.startsWith('user-') &&
        _mealDetailForUserRecipeId(d.id) != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _RecipeCommitSheet(
          detail: d,
          isFavorite: _favorites.any((x) => x.id == d.id),
          onFavoriteToggle: () async {
            final now = await RecipeFavoritesStore.toggle(_summaryFromDetail(d));
            await _loadFavorites();
            if (mounted) setState(() {});
            return now;
          },
          onEditMyRecipe: showEdit
              ? () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_goEditRecipeById(d.id));
                  });
                }
              : null,
          onCommit: (selectedIngredients, checklistSteps) async {
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (!mounted) return;
            await widget.onAddRecipeToTodoAndBag(
              d.name,
              selectedIngredients,
              checklistSteps,
            );
          },
        );
      },
    );
  }

  Future<void> _openUserRecipe(UserRecipe recipe) async {
    final d = MealDetail(
      id: recipe.id,
      name: recipe.name,
      thumbUrl: recipe.thumbUrl,
      description: recipe.description,
      searchTags: List<String>.from(recipe.searchTags),
      ingredientLines: List<String>.from(recipe.ingredientLines),
      stepLines: List<String>.from(recipe.stepLines),
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _RecipeCommitSheet(
          detail: d,
          isFavorite: _favorites.any((x) => x.id == d.id),
          onFavoriteToggle: () async {
            final now = await RecipeFavoritesStore.toggle(_summaryFromDetail(d));
            await _loadFavorites();
            if (mounted) setState(() {});
            return now;
          },
          onEditMyRecipe: () {
            Navigator.of(ctx).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_goEditRecipe(recipe));
            });
          },
          onCommit: (selectedIngredients, checklistSteps) async {
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (!mounted) return;
            await widget.onAddRecipeToTodoAndBag(
              d.name,
              selectedIngredients,
              checklistSteps,
            );
          },
        );
      },
    );
  }

  Future<void> _goEditRecipe(UserRecipe recipe) async {
    await Navigator.of(context).push<UserRecipe>(
      MaterialPageRoute<UserRecipe>(
        builder: (context) => CreateUserRecipePage(
          existingRecipe: recipe,
          onPersistBeforePop: widget.onPersistUserRecipe,
        ),
      ),
    );
  }

  Future<void> _goEditRecipeById(String id) async {
    UserRecipe? recipe;
    for (final r in widget.customRecipes) {
      if (r.id == id) {
        recipe = r;
        break;
      }
    }
    if (recipe != null) await _goEditRecipe(recipe);
  }

  Future<void> _goCreateRecipe() async {
    await Navigator.of(context).push<UserRecipe>(
      MaterialPageRoute<UserRecipe>(
        builder: (context) => CreateUserRecipePage(
          onPersistBeforePop: widget.onPersistUserRecipe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blendBorder = Theme.of(context).scaffoldBackgroundColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'My recipes (${widget.customRecipes.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
        ),
        SizedBox(
          height: 112,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: widget.customRecipes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 64, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Create your own recipes from right button. Shopping bag is at the bottom right corner.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 64, 0),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.customRecipes.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final r = widget.customRecipes[index];
                          return SizedBox(
                            width: 88,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Material(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () =>
                                          unawaited(_openUserRecipe(r)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: CachedNetworkImage(
                                              imageUrl: r.displayThumbUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, _) =>
                                                  ColoredBox(
                                                color: scheme.surface,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: scheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (_, _, _) =>
                                                  ColoredBox(
                                                color: scheme.surface,
                                                child: Icon(
                                                  Icons.restaurant,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              4,
                                              4,
                                              4,
                                              2,
                                            ),
                                            child: Text(
                                              r.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Material(
                                    color: scheme.surface.withValues(
                                      alpha: 0.92,
                                    ),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () =>
                                          unawaited(_goEditRecipe(r)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Material(
                                    color: scheme.surface.withValues(
                                      alpha: 0.92,
                                    ),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () =>
                                          unawaited(widget.onDeleteUserRecipe(r.id)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: scheme.primaryContainer,
                    shape: const CircleBorder(),
                    elevation: 1,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => unawaited(_goCreateRecipe()),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.add_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    unawaited(_runSearch());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search (e.g. chicken) — TheMealDB + public recipes',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: blendBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: blendBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: blendBorder, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _searching
                    ? null
                    : () {
                        unawaited(_runSearch());
                      },
                child: _searching
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(Icons.search_rounded, color: scheme.onPrimary),
              ),
            ],
          ),
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _searchError!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const hPad = 32.0;
                    const between = 10.0;
                    final inner = constraints.maxWidth - hPad;
                    final cardW = (inner - between) / 2;
                    final cardH = (cardW / 0.84).clamp(
                      168.0,
                      constraints.maxHeight * 0.46,
                    );

                    if (_results.isEmpty && _favorites.isEmpty) {
                      return Center(
                        child: Text(
                          _searchError == null
                              ? 'No recipes match.\nTry another word or clear the search.'
                              : 'No results — try another word.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_results.isNotEmpty)
                            SizedBox(
                              height: cardH,
                              child: _horizontalRecipeCarousel(
                                items: _results,
                                cardW: cardW,
                                cardH: cardH,
                                scheme: scheme,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                8,
                                24,
                                0,
                              ),
                              child: Text(
                                '検索に一致するレシピがありません。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (_favorites.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: Text(
                                'あなたのお気に入り',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                              ),
                            ),
                            SizedBox(
                              height: cardH,
                              child: _horizontalRecipeCarousel(
                                items: _favorites,
                                cardW: cardW,
                                cardH: cardH,
                                scheme: scheme,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Full photo on top of a blurred, cropped version of the same image (letterbox fill).
class _RecipeGridThumb extends StatelessWidget {
  const _RecipeGridThumb({
    required this.imageUrl,
    required this.scheme,
  });

  final String imageUrl;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final loading = ColoredBox(
          color: scheme.surface,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
        final error = ColoredBox(
          color: scheme.surface,
          child: Icon(
            Icons.restaurant,
            size: 32,
            color: scheme.onSurfaceVariant,
          ),
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Transform.scale(
                    scale: 1.1,
                    alignment: Alignment.center,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: w,
                      height: h,
                      placeholder: (_, __) => ColoredBox(color: scheme.surface),
                      errorWidget: (_, __, ___) =>
                          ColoredBox(color: scheme.surface),
                    ),
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => loading,
                    errorWidget: (_, __, ___) => error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecipeCommitSheet extends StatefulWidget {
  const _RecipeCommitSheet({
    required this.detail,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.onEditMyRecipe,
    required this.onCommit,
  });

  final MealDetail detail;
  final bool isFavorite;
  final Future<bool> Function() onFavoriteToggle;
  /// When set, shows an Edit control for the user’s own recipe.
  final VoidCallback? onEditMyRecipe;
  final Future<void> Function(
    List<String> selectedIngredients,
    List<String> checklistSteps,
  ) onCommit;

  @override
  State<_RecipeCommitSheet> createState() => _RecipeCommitSheetState();
}

class _RecipeCommitSheetState extends State<_RecipeCommitSheet> {
  /// Indices of ingredients marked for the shopping bag (green check when on).
  final Set<int> _bagIngredientIndexes = <int>{};
  late bool _favorite;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.isFavorite;
  }

  @override
  void didUpdateWidget(covariant _RecipeCommitSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.id != widget.detail.id) {
      _favorite = widget.isFavorite;
    }
  }

  void _setBagForAll(
    bool select) {
    setState(() {
      _bagIngredientIndexes.clear();
      if (select) {
        _bagIngredientIndexes.addAll(
          List.generate(widget.detail.ingredientLines.length, (i) => i),
        );
      }
    });
  }

  void _toggleBagIndex(int index) {
    setState(() {
      if (_bagIngredientIndexes.contains(index)) {
        _bagIngredientIndexes.remove(index);
      } else {
        _bagIngredientIndexes.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.detail;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                d.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              if (widget.onEditMyRecipe != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onEditMyRecipe,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Edit recipe'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _favoriteBusy
                    ? null
                    : () async {
                        setState(() => _favoriteBusy = true);
                        try {
                          final v = await widget.onFavoriteToggle();
                          if (mounted) setState(() => _favorite = v);
                        } finally {
                          if (mounted) {
                            setState(() => _favoriteBusy = false);
                          }
                        }
                      },
                icon: Icon(
                  _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _favorite ? scheme.primary : scheme.onSurfaceVariant,
                ),
                label: Text(
                  _favorite ? 'お気に入りを解除' : 'お気に入りに追加',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: d.displayThumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.restaurant,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (d.description != null && d.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  d.description!.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (d.searchTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tags',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in d.searchTags)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          t,
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Ingredients — tap “Add to bag”; a green check means it will go to your bag.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              if (d.ingredientLines.isEmpty)
                Text(
                  'No ingredient list for this recipe (task steps are still added).',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _setBagForAll(true),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text('Add all to bag'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _setBagForAll(false),
                      icon: const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                      label: const Text('Clear bag picks'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                ...List.generate(d.ingredientLines.length, (i) {
                  final line = d.ingredientLines[i];
                  final inBag = _bagIngredientIndexes.contains(i);
                  const bagCheckGreen = Color(0xFF2E7D32);
                  const bagCheckGreenDark = Color(0xFF66BB6A);
                  final checkColor = Theme.of(context).brightness == Brightness.dark
                      ? bagCheckGreenDark
                      : bagCheckGreen;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            Tooltip(
                              message:
                                  inBag ? 'Tap to remove from bag' : 'Add to bag',
                              child: OutlinedButton.icon(
                                onPressed: () => _toggleBagIndex(i),
                                icon: Icon(
                                  inBag ? Icons.check_circle_rounded : Icons.add_rounded,
                                  size: 18,
                                  color: inBag ? checkColor : scheme.primary,
                                ),
                                label: Text(
                                  inBag ? 'In bag' : 'Add to bag',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: inBag ? checkColor : scheme.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  side: BorderSide(
                                    color: inBag ? checkColor : scheme.outline,
                                    width: inBag ? 1.5 : 1,
                                  ),
                                  backgroundColor: inBag
                                      ? checkColor.withValues(alpha: 0.12)
                                      : scheme.primary.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Steps — these become your task checklist.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (d.stepLines.isEmpty)
                Text(
                  'No written steps; we will add a single “Cook this recipe” checklist item.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                )
              else
                ...d.stepLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '· ',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: scheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final idx = _bagIngredientIndexes.toList()..sort();
                  final selected = idx
                      .map((i) => d.ingredientLines[i].trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  await widget.onCommit(selected, d.stepLines);
                },
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Add to today’s todo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
