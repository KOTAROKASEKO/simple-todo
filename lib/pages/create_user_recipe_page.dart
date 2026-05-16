import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simpletodo/health/user_recipe.dart';

/// Create or edit a [UserRecipe] and return it via [Navigator.pop].
class CreateUserRecipePage extends StatefulWidget {
  const CreateUserRecipePage({
    super.key,
    this.existingRecipe,
    this.onPersistBeforePop,
  });

  /// When set, the page edits this recipe (same [UserRecipe.id] on save).
  final UserRecipe? existingRecipe;

  /// Writes to Firestore before [Navigator.pop]; receives `isNew` for `createdAt`.
  final Future<void> Function(UserRecipe recipe, {required bool isNew})?
      onPersistBeforePop;

  @override
  State<CreateUserRecipePage> createState() => _CreateUserRecipePageState();
}

class _CreateUserRecipePageState extends State<CreateUserRecipePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isPublic = false;
  XFile? _pickedImage;
  Uint8List? _previewBytes;
  /// In edit mode: user removed the image without picking a new one.
  bool _imageCleared = false;
  bool _uploading = false;

  bool get _isEditing => widget.existingRecipe != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingRecipe;
    if (e != null) {
      _titleController.text = e.name;
      if (e.description != null && e.description!.trim().isNotEmpty) {
        _descriptionController.text = e.description!.trim();
      }
      _ingredientsController.text = e.ingredientLines.join('\n');
      _stepsController.text = e.stepLines.join('\n');
      _isPublic = e.isPublic;
      if (e.searchTags.isNotEmpty) {
        _tagsController.text = e.searchTags.join('\n');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  String _guessImageExtension(String pathOrName) {
    final dot = pathOrName.lastIndexOf('.');
    if (dot <= 0 || dot >= pathOrName.length - 1) return 'jpg';
    final ext = pathOrName.substring(dot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String? _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (!mounted || x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = x;
      _previewBytes = bytes;
      _imageCleared = false;
    });
  }

  void _clearPickedImage() {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
      if (_isEditing) {
        _imageCleared = true;
      }
    });
  }

  Future<String> _uploadRecipeImage({
    required String userId,
    required String recipeId,
    required XFile xfile,
  }) async {
    final storage = FirebaseStorage.instance;
    final nameOrPath =
        xfile.name.isNotEmpty ? xfile.name : (xfile.path.isNotEmpty ? xfile.path : 'image.jpg');
    final ext = _guessImageExtension(nameOrPath);
    final objectPath = 'todo/$userId/recipe_images/$recipeId.$ext';
    final ref = storage.ref(objectPath);
    final meta = SettableMetadata(contentType: _contentTypeForExtension(ext));
    if (kIsWeb) {
      final bytes = await xfile.readAsBytes();
      await ref.putData(bytes, meta);
    } else {
      final file = File(xfile.path);
      if (!await file.exists()) {
        throw StateError('The selected image file could not be found.');
      }
      await ref.putFile(file, meta);
    }
    return ref.getDownloadURL();
  }

  List<String> _linesFromMultiline(String raw) {
    return raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name.')),
      );
      return;
    }
    if (_uploading) return;

    final existing = widget.existingRecipe;
    final id = existing?.id ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    String? thumbUrl;

    if (_pickedImage != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to upload images.'),
          ),
        );
        return;
      }
      setState(() => _uploading = true);
      try {
        thumbUrl = await _uploadRecipeImage(
          userId: user.uid,
          recipeId: id,
          xfile: _pickedImage!,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } else if (existing != null) {
      if (_imageCleared) {
        thumbUrl = null;
      } else {
        final u = existing.thumbUrl?.trim();
        thumbUrl = u != null && u.isNotEmpty ? u : null;
      }
    }

    if (!mounted) return;
    final desc = _descriptionController.text.trim();
    final tags = UserRecipe.normalizeSearchTags(_tagsController.text);
    final recipe = UserRecipe(
      id: id,
      name: title,
      thumbUrl: thumbUrl,
      description: desc.isEmpty ? null : desc,
      ingredientLines: _linesFromMultiline(_ingredientsController.text),
      stepLines: _linesFromMultiline(_stepsController.text),
      isPublic: _isPublic,
      searchTags: tags,
    );

    final persist = widget.onPersistBeforePop;
    if (persist != null) {
      try {
        await persist(recipe, isNew: widget.existingRecipe == null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save recipe: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop<UserRecipe>(recipe);
  }

  Widget _buildImagePreview(ColorScheme scheme) {
    if (_previewBytes != null) {
      return Image.memory(
        _previewBytes!,
        fit: BoxFit.cover,
      );
    }
    final e = widget.existingRecipe;
    if (e != null &&
        !_imageCleared &&
        (e.thumbUrl?.trim().isNotEmpty ?? false)) {
      return CachedNetworkImage(
        imageUrl: e.thumbUrl!.trim(),
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(
          color: scheme.surface,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  bool get _showClearImageButton {
    if (_pickedImage != null) return true;
    final e = widget.existingRecipe;
    if (e != null && !_imageCleared && (e.thumbUrl?.trim().isNotEmpty ?? false)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blendBorder = Theme.of(context).scaffoldBackgroundColor;

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
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
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit recipe' : 'Create recipe'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : () => _save(),
            child: _uploading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: deco('Recipe name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                textInputAction: TextInputAction.next,
                minLines: 2,
                maxLines: 4,
                decoration: deco('Description (optional)'),
              ),
              const SizedBox(height: 16),
              Text(
                'Image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: _buildImagePreview(scheme),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _uploading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose photo'),
                  ),
                  if (_showClearImageButton) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _uploading ? null : _clearPickedImage,
                      child: const Text('Clear image'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gallery photos upload to the cloud when you save (sign-in required).',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ingredients (one per line)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _ingredientsController,
                minLines: 4,
                maxLines: 10,
                decoration: deco('e.g. 2 cups rice'),
              ),
              const SizedBox(height: 16),
              Text(
                'Steps (one per line)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _stepsController,
                minLines: 4,
                maxLines: 12,
                decoration: deco('e.g. Rinse the rice'),
              ),
              const SizedBox(height: 16),
              Text(
                'Search tags (one per line)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _tagsController,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: deco('e.g. fish\nquick\nweekday'),
              ),
              const SizedBox(height: 6),
              Text(
                'Each line is one tag (search / Algolia). Stored lowercase; optional # prefix is ignored.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish publicly'),
                subtitle: Text(
                  'When on, this recipe also appears in search below. It always appears under My recipes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                value: _isPublic,
                onChanged: _uploading ? null : (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _uploading ? null : _save,
                child: Text(_isEditing ? 'Save changes' : 'Save and go back'),
              ),
            ],
          ),
          if (_uploading)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: scheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Uploading image…',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
