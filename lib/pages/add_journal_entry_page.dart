import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:simpletodo/journal_image_cache.dart';
import 'package:simpletodo_data_core/simpletodo_data_core.dart';
import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

/// Full-screen journal entry page with a single text field that expands
/// to fill the screen. Save writes to Firestore and pops.
class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({
    super.key,
    required this.journalRef,
    this.journalStore,
  });

  final CollectionReference<Map<String, dynamic>> journalRef;

  /// When set (mobile local store mode), mirrors remote create immediately.
  final JournalLocalStore? journalStore;

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  static const String _kDefaultJournalCategory = 'diary';

  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;
  final List<_JournalDraftImage> _images = [];
  final ImagePicker _picker = ImagePicker();
  String? _draftEntryId;

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

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
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
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'image/jpeg';
    }
  }

  Future<String> _uploadJournalImageNow({
    required String userId,
    required String localPath,
  }) async {
    final storage = FirebaseStorage.instance;
    final entryId = _draftEntryId ??= widget.journalRef.doc().id;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError(
        'A photo file is no longer available. Please add your photos again.',
      );
    }
    final ext = _guessImageExtension(localPath);
    final objectPath =
        'todo/$userId/journal_entries/$entryId/${stamp}_${localPath.hashCode}.$ext';
    final ref = storage.ref(objectPath);
    await ref.putFile(
      file,
      SettableMetadata(contentType: _contentTypeForExtension(ext)),
    );
    return ref.getDownloadURL();
  }

  Future<void> _saveJournalEntry() async {
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
      final docRef = (_draftEntryId != null)
          ? widget.journalRef.doc(_draftEntryId)
          : widget.journalRef.doc();
      final mediaRefs = _images
          .where((img) => img.uploadedUrl != null && img.error == null)
          .map((img) => img.uploadedUrl!)
          .toList();
      final imageRefsForWarmCache = _images
          .where(
            (img) =>
                !img.isVideo && img.uploadedUrl != null && img.error == null,
          )
          .map((img) => img.uploadedUrl!)
          .toList();
      final now = DateTime.now();
      final data = <String, dynamic>{
        'content': content,
        'category': _kDefaultJournalCategory,
        'order': now.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        // AI reply requests are manual from journal long-press actions.
        'journalAiFeedbackRequested': false,
      };
      if (mediaRefs.isNotEmpty) {
        data['imagePaths'] = mediaRefs;
      }
      await docRef.set(data);
      await widget.journalStore
          ?.ingestAfterRemoteCreate(docRef.id, <String, dynamic>{
            'content': content,
            'category': _kDefaultJournalCategory,
            'order': now.millisecondsSinceEpoch,
            'createdAt': Timestamp.fromDate(now),
            'journalAiFeedbackRequested': false,
            if (mediaRefs.isNotEmpty) 'imagePaths': mediaRefs,
          });
      if (!mounted) return;
      if (imageRefsForWarmCache.isNotEmpty) {
        unawaited(warmJournalImageDiskCache(imageRefsForWarmCache));
        unawaited(warmJournalImageMemoryCache(context, imageRefsForWarmCache));
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImages() async {
    if (_isSaving) return;
    try {
      final picked = await _picker.pickMultiImage(limit: 30);
      if (picked.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to add photos.')),
        );
        return;
      }
      for (final x in picked) {
        if (x.path.isEmpty) continue;
        final image = _JournalDraftImage(localPath: x.path);
        image.isVideo = _isVideoPath(x.path);
        setState(() => _images.add(image));
        try {
          final url = await _uploadJournalImageNow(
            userId: user.uid,
            localPath: x.path,
          );
          if (!mounted) return;
          setState(() {
            image.uploadedUrl = url;
            image.isUploading = false;
          });
          unawaited(warmJournalImageDiskCache([url]));
        } catch (e) {
          if (!mounted) return;
          setState(() {
            image.error = e.toString();
            image.isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload a photo: $e')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  Future<void> _pickVideo() async {
    if (_isSaving) return;
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || picked.path.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to add videos.')),
        );
        return;
      }
      final media = _JournalDraftImage(localPath: picked.path)..isVideo = true;
      setState(() => _images.add(media));
      try {
        final url = await _uploadJournalImageNow(
          userId: user.uid,
          localPath: picked.path,
        );
        if (!mounted) return;
        setState(() {
          media.uploadedUrl = url;
          media.isUploading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          media.error = e.toString();
          media.isUploading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload video: $e')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
    }
  }

  Future<void> _showMediaPickerSheet() async {
    if (_isSaving) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Add photos'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Add a video'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeImageAt(int index) {
    final image = _images[index];
    setState(() => _images.removeAt(index));
    final url = image.uploadedUrl;
    if (url != null && url.isNotEmpty) {
      FirebaseStorage.instance.refFromURL(url).delete().catchError((_) {});
    }
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
    if (_images.any((img) => img.isUploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for photo uploads to finish.'),
        ),
      );
      return;
    }
    if (_images.any((img) => img.error != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some photos failed to upload. Remove them or add again.',
          ),
        ),
      );
      return;
    }
    _saveJournalEntry();
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
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_BackAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_BackAction.discard),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_BackAction.save),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    // When the keyboard is up, the body is already laid out above it; keep only
    // a small gap so thumbnails don't sit under the FAB. Avoid the full FAB +
    // safe-area reserve, which reads as a large empty strip above the keyboard.
    final bottomPadding = keyboardOpen ? 10.0 : mq.padding.bottom + 72;
    final appBar = AppBar(
      flexibleSpace: const LiquidGlassAppBarBackground(),
      foregroundColor: scheme.onSurface,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'New entry',
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
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
                : Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
            label: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
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
        backgroundColor: pageBg,
        floatingActionButton: FloatingActionButton(
          heroTag: 'journal_add_photos',
          onPressed: _isSaving ? null : _showMediaPickerSheet,
          tooltip: 'Add media',
          backgroundColor: isDark ? scheme.primary : const Color(0xFFDFE2EA),
          foregroundColor: isDark ? scheme.onPrimary : const Color(0xFF1C1E24),
          child: const Icon(Icons.add_photo_alternate_rounded),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        appBar: appBar,
        body: Padding(
          padding: EdgeInsets.only(
            top:
                MediaQuery.paddingOf(context).top + appBar.preferredSize.height,
          ),
          child: SafeArea(
            top: false,
            bottom: !keyboardOpen,
            child: SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
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
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: pageBg),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: pageBg),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: pageBg,
                              width: 1.2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            20,
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final img = _images[index];
                            final path = img.localPath;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                _JournalAddMediaPreview(
                                  filePath: path,
                                  isVideo: img.isVideo,
                                ),
                                if (img.isUploading)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black26,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (img.error != null)
                                  Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Failed',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
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

/// Local photo chip: full image with [BoxFit.contain], letterbox filled by a blurred [BoxFit.cover] layer.
class _JournalAddMediaPreview extends StatelessWidget {
  const _JournalAddMediaPreview({
    required this.filePath,
    required this.isVideo,
  });

  final String filePath;
  final bool isVideo;
  static const double _blurSigma = 12;

  Widget _image(BoxFit fit) {
    return Image.file(
      File(filePath),
      fit: fit,
      errorBuilder: (context, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _layer(BoxFit fit, {required bool blurred}) {
    final core = _image(fit);
    if (!blurred) return core;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
      child: Transform.scale(scale: 1.08, child: core),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 88,
          height: 88,
          child: ColoredBox(
            color: Colors.black87,
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88,
        height: 88,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _layer(BoxFit.cover, blurred: true),
              Positioned.fill(child: _layer(BoxFit.contain, blurred: false)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BackAction { cancel, discard, save }

class _JournalDraftImage {
  _JournalDraftImage({required this.localPath});

  final String localPath;
  String? uploadedUrl;
  String? error;
  bool isUploading = true;
  bool isVideo = false;
}
