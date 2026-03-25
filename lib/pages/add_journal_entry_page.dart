import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

/// Full-screen journal entry page with a single text field that expands
/// to fill the screen. Save writes to Firestore and pops.
class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({
    super.key,
    required this.journalRef,
  });

  final CollectionReference<Map<String, dynamic>> journalRef;

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}


const List<String> _kJournalCategories = ['diary', 'work', 'life'];

String _categoryLabel(String value) {
  switch (value) {
    case 'diary':
      return 'Diary';
    case 'work':
      return 'Work';
    case 'life':
      return 'Life';
    default:
      return value;
  }
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;
  final List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  bool get _hasUnsavedText => _contentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _guessImageExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
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

  Future<List<String>> _uploadJournalImages({
    required String userId,
    required String entryId,
    required List<String> localPaths,
  }) async {
    final storage = FirebaseStorage.instance;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];
    for (var i = 0; i < localPaths.length; i++) {
      final localPath = localPaths[i];
      final file = File(localPath);
      if (!await file.exists()) {
        throw StateError(
          'A photo file is no longer available. Please add your photos again.',
        );
      }
      final ext = _guessImageExtension(localPath);
      final objectPath =
          'todo/$userId/journal_entries/$entryId/${stamp}_$i.$ext';
      final ref = storage.ref(objectPath);
      await ref.putFile(
        file,
        SettableMetadata(contentType: _contentTypeForExtension(ext)),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _saveWithCategory(String category) async {
    final content = _contentController.text.trim();
    assert(content.isNotEmpty);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to save.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final docRef = widget.journalRef.doc();
      final entryId = docRef.id;
      List<String> imageRefs = [];
      if (_imagePaths.isNotEmpty) {
        imageRefs = await _uploadJournalImages(
          userId: user.uid,
          entryId: entryId,
          localPaths: _imagePaths,
        );
      }
      final now = DateTime.now();
      final data = <String, dynamic>{
        'content': content,
        'category': category,
        'order': now.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageRefs.isNotEmpty) {
        data['imagePaths'] = imageRefs;
      }
      await docRef.set(data);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImages() async {
    if (_isSaving) return;
    try {
      final picked = await _picker.pickMultiImage(limit: 30);
      if (picked.isEmpty) return;
      setState(() {
        for (final x in picked) {
          if (x.path.isNotEmpty) _imagePaths.add(x.path);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  void _removeImageAt(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  void _onSaveTapped() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    if (_isSaving) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Choose category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              ..._kJournalCategories.map((category) {
                return ListTile(
                  title: Text(_categoryLabel(category)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveWithCategory(category);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_isSaving) {
      return false;
    }
    if (!_hasUnsavedText) {
      return true;
    }

    final action = await showDialog<_BackAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save journal entry?'),
          content: const Text(
            'You have unsaved text. Do you want to save before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_BackAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_BackAction.discard),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(_BackAction.save),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (action == _BackAction.discard) {
      return true;
    }
    if (action == _BackAction.save) {
      _onSaveTapped();
      return false;
    }
    return false;
  }

  static const Color _pageBackground = Color(0xFFF8F9FC);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    // When the keyboard is up, the body is already laid out above it; keep only
    // a small gap so thumbnails don't sit under the FAB. Avoid the full FAB +
    // safe-area reserve, which reads as a large empty strip above the keyboard.
    final bottomPadding = keyboardOpen
        ? 10.0
        : mq.padding.bottom + 72;
    final appBar = AppBar(
      flexibleSpace: const LiquidGlassAppBarBackground(),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'New entry',
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: Colors.grey.shade700),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _isSaving ? null : _onSaveTapped,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Icon(Icons.check_rounded, size: 20, color: Colors.grey.shade700),
            label: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _handleWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _pageBackground,
        floatingActionButton: FloatingActionButton(
          heroTag: 'journal_add_photos',
          onPressed: _isSaving ? null : _pickImages,
          tooltip: 'Add photos',
          child: const Icon(Icons.add_photo_alternate_rounded),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        appBar: appBar,
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + appBar.preferredSize.height,
          ),
          child: SafeArea(
            top: false,
            bottom: !keyboardOpen,
            child: SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _pageBackground),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _pageBackground),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _pageBackground),
                          ),
                          contentPadding: const EdgeInsets.all(20),
                          filled: true,
                          fillColor: _pageBackground,
                        ),
                      ),
                    ),
                    if (_imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagePaths.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final path = _imagePaths[index];
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 88,
                                    height: 88,
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, _, __) =>
                                          Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _removeImageAt(index),
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BackAction { cancel, discard, save }
