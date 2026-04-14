import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:simpletodo/journal_ai_character_assets.dart';
import 'package:simpletodo/journal_image_cache.dart';
import 'package:simpletodo/journal_ai_unlock.dart';
import 'package:simpletodo/services/journal_character_unlock.dart';
import 'package:simpletodo_data/simpletodo_data.dart';
import 'package:simpletodo/widgets/journal_ai_character_avatar.dart';
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
  /// When set (mobile), the new doc is mirrored into Isar immediately.
  final JournalStore? journalStore;

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
  static const String _prefJournalAiFeedback = 'journal_ai_feedback_enabled';
  static const String _kNoShareId = '__no_share__';
  static const Map<String, String> _kCharacterLabels = {
    'default': 'Default assistant',
    'gyaru': '美咲 · gyaru AI',
    'kopitiam_uncle': 'Wong · kopitiam uncle AI',
    'chinese_auntie': 'Yin · auntie AI',
  };
  static const Map<String, String> _kCharacterDescriptions = {
    'default':
        'Hi everyone. I usually respond like a warm, thoughtful therapist-style companion.',
    'gyaru':
        "I'm super positive! You can totally talk to me about anything - even wild stories, no judgment, haha!",
    'kopitiam_uncle':
        'Wah... everyone is working so hard, good job ah. Let\'s take it one practical step at a time.',
    'chinese_auntie':
        'Hey you! Bring me your journal - auntie is here to push you forward with love and energy!',
  };

  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;
  final List<_JournalDraftImage> _images = [];
  final ImagePicker _picker = ImagePicker();
  String? _draftEntryId;
  /// Persisted default for category sheet: whether surprise AI feedback is requested.
  bool _journalAiFeedbackEnabled = true;
  String _journalAiCharacter = 'default';
  /// Same as Firestore `journalDailyReminderGreetingName` (呼び名・通知用).
  String _journalGreetingName = '';
  static const int _kJournalGreetingMaxChars = 40;
  List<String> _unlockedJournalIds = [kJournalAiDefaultCharacterId];

  bool get _hasUnsavedText => _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadJournalAiSettings();
  }

  Future<void> _loadJournalAiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    String character = 'default';
    if (user != null) {
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('todo')
            .doc(user.uid)
            .get();
        final uData = userSnap.data() ?? <String, dynamic>{};
        if (mounted) {
          _unlockedJournalIds =
              parseUnlockedJournalCharacters(uData['unlockedJournalAiCharacters']);
        }
        final raw = uData['journalAiCharacter'];
        if (raw is String && _kCharacterLabels.containsKey(raw)) {
          character = raw;
        }
        if (!isJournalCharacterUnlockedForList(character, _unlockedJournalIds)) {
          character = kJournalAiDefaultCharacterId;
        }
        final greet = userSnap.data()?['journalDailyReminderGreetingName'];
        if (greet is String && mounted) {
          _journalGreetingName = greet;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _journalAiFeedbackEnabled = prefs.getBool(_prefJournalAiFeedback) ?? true;
      _journalAiCharacter = character;
    });
  }

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
      final docRef = (_draftEntryId != null)
          ? widget.journalRef.doc(_draftEntryId)
          : widget.journalRef.doc();
      final imageRefs = _images
          .where((img) => img.uploadedUrl != null && img.error == null)
          .map((img) => img.uploadedUrl!)
          .toList();
      final now = DateTime.now();
      final data = <String, dynamic>{
        'content': content,
        'category': category,
        'order': now.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        'journalAiFeedbackRequested': _journalAiFeedbackEnabled,
      };
      if (imageRefs.isNotEmpty) {
        data['imagePaths'] = imageRefs;
      }
      await docRef.set(data);
      await widget.journalStore?.ingestAfterRemoteCreate(
        docRef.id,
        <String, dynamic>{
          'content': content,
          'category': category,
          'order': now.millisecondsSinceEpoch,
          'createdAt': Timestamp.fromDate(now),
          'journalAiFeedbackRequested': _journalAiFeedbackEnabled,
          if (imageRefs.isNotEmpty) 'imagePaths': imageRefs,
        },
      );
      if (!mounted) return;
      if (imageRefs.isNotEmpty) {
        unawaited(warmJournalImageDiskCache(imageRefs));
        unawaited(warmJournalImageMemoryCache(context, imageRefs));
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  void _removeImageAt(int index) {
    final image = _images[index];
    setState(() => _images.removeAt(index));
    final url = image.uploadedUrl;
    if (url != null && url.isNotEmpty) {
      FirebaseStorage.instance
          .refFromURL(url)
          .delete()
          .catchError((_) {});
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
        const SnackBar(content: Text('Please wait for photo uploads to finish.')),
      );
      return;
    }
    if (_images.any((img) => img.error != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some photos failed to upload. Remove them or add again.'),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          const aiPurple = Color(0xFF6366F1);

          return SafeArea(
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do u wanna share your journal with AI?',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'They might be slow texters. forgive them',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: _kCharacterLabels.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                                  final isNoShare = index == 0;
                                  final id = isNoShare
                                      ? _kNoShareId
                                      : _kCharacterLabels.keys.elementAt(index - 1);
                                  final isSelected = isNoShare
                                      ? !_journalAiFeedbackEnabled
                                      : (_journalAiFeedbackEnabled &&
                                          id == _journalAiCharacter);
                                  final icon = kJournalAiCharacterIcons[id] ??
                                      (isNoShare
                                          ? Icons.block_rounded
                                          : Icons.smart_toy_outlined);
                                  final label =
                                      isNoShare ? 'シェアしない' : (_kCharacterLabels[id] ?? id);
                                  final desc =
                                      isNoShare
                                          ? 'この投稿は AI にシェアしません。'
                                          : (_kCharacterDescriptions[id] ?? '');
                                  final locked = !isNoShare &&
                                      !isJournalCharacterUnlockedForList(
                                        id,
                                        _unlockedJournalIds,
                                      );
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () async {
                                      if (isNoShare) {
                                        setState(() {
                                          _journalAiFeedbackEnabled = false;
                                        });
                                        setModalState(() {});
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setBool(
                                          _prefJournalAiFeedback,
                                          false,
                                        );
                                        return;
                                      }
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null &&
                                          !isJournalCharacterUnlockedForList(
                                            id,
                                            _unlockedJournalIds,
                                          )) {
                                        final cost =
                                            unlockCostForJournalCharacter(id);
                                        final unlock = await showDialog<bool>(
                                          context: sheetContext,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(
                                              'Unlock ${_kCharacterLabels[id] ?? id}?',
                                            ),
                                            content: Text(
                                              'Spend $cost task coins to use this voice. '
                                              'You can also unlock from Journal AI notes in settings.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Unlock'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (unlock != true || !mounted) return;
                                        final r = await unlockJournalCharacterWithCoins(
                                          uid: user.uid,
                                          characterId: id,
                                        );
                                        if (!mounted) return;
                                        if (r == JournalUnlockResult.notEnoughCoins) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Not enough coins.'),
                                            ),
                                          );
                                          return;
                                        }
                                        if (r == JournalUnlockResult.error) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not unlock. Try again.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() {
                                          if (!_unlockedJournalIds.contains(id)) {
                                            _unlockedJournalIds = [
                                              ..._unlockedJournalIds,
                                              id,
                                            ]..sort();
                                          }
                                        });
                                      }
                                      final nicknameCtrl = TextEditingController(
                                        text: _journalGreetingName,
                                      );
                                      final shouldUse = await showDialog<bool>(
                                        context: sheetContext,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  child: ClipOval(
                                                    child:
                                                        JournalAiCharacterAvatar(
                                                      characterId: id,
                                                      size: 60,
                                                      iconColor: Colors
                                                          .grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(label),
                                              ],
                                            ),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(desc),
                                                  const SizedBox(height: 16),
                                                  TextField(
                                                    controller: nicknameCtrl,
                                                    maxLength:
                                                        _kJournalGreetingMaxChars,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          '呼ばれたい名前（通知の冒頭など）',
                                                      hintText: '例：ねね',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(false),
                                                child: const Text('Close'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(true),
                                                child: const Text('このキャラを使う'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      final nickTrim =
                                          nicknameCtrl.text.trim();
                                      // Dialog route can still be unmounting when
                                      // showDialog completes; defer dispose so the
                                      // TextField is not attached to a disposed controller.
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        nicknameCtrl.dispose();
                                      });
                                      if (!mounted) return;
                                      if (shouldUse == true) {
                                        if (nickTrim.length >
                                            _kJournalGreetingMaxChars) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '名前は$_kJournalGreetingMaxChars文字までです。',
                                                ),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        setState(() {
                                          _journalAiCharacter = id;
                                          _journalAiFeedbackEnabled = true;
                                          _journalGreetingName = nickTrim;
                                        });
                                        setModalState(() {});
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setBool(
                                          _prefJournalAiFeedback,
                                          true,
                                        );
                                        final user =
                                            FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          await FirebaseFirestore.instance
                                              .collection('todo')
                                              .doc(user.uid)
                                              .set(
                                            {
                                              'journalAiCharacter': id,
                                              'journalDailyReminderGreetingName':
                                                  nickTrim,
                                            },
                                            SetOptions(merge: true),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? aiPurple.withValues(alpha: 0.12)
                                            : locked
                                                ? Colors.grey.shade200
                                                : Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: isSelected
                                            ? Border.all(
                                                color: aiPurple
                                                    .withValues(alpha: 0.45),
                                              )
                                            : locked
                                                ? Border.all(
                                                    color: Colors.grey.shade400,
                                                  )
                                                : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: isNoShare
                                          ? Icon(
                                              icon,
                                              size: 20,
                                              color: isSelected
                                                  ? aiPurple
                                                  : Colors.grey.shade600,
                                            )
                                          : Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                ClipOval(
                                                  child: SizedBox(
                                                    width: 34,
                                                    height: 34,
                                                    child:
                                                        JournalAiCharacterAvatar(
                                                      characterId: id,
                                                      size: 34,
                                                      muted: locked,
                                                      iconColor: locked
                                                          ? Colors.grey.shade500
                                                          : isSelected
                                                              ? aiPurple
                                                              : Colors
                                                                  .grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                if (locked)
                                                  Positioned(
                                                    right: -1,
                                                    bottom: -1,
                                                    child: Material(
                                                      elevation: 1.5,
                                                      shadowColor:
                                                          Colors.black26,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        5,
                                                      ),
                                                      color: Colors.white,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 3,
                                                          vertical: 2,
                                                        ),
                                                        child: Icon(
                                                          Icons.lock_rounded,
                                                          size: 11,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ..._kJournalCategories.map((category) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _saveWithCategory(category);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _categoryLabel(category),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            20,
                          ),
                          filled: true,
                          fillColor: _pageBackground,
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final img = _images[index];
                            final path = img.localPath;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                _JournalAddPhotoPreview(filePath: path),
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
class _JournalAddPhotoPreview extends StatelessWidget {
  const _JournalAddPhotoPreview({required this.filePath});

  final String filePath;
  static const double _blurSigma = 12;

  Widget _image(BoxFit fit) {
    return Image.file(
      File(filePath),
      fit: fit,
      errorBuilder: (context, _, _) => ColoredBox(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 24),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88,
        height: 88,
        child: ColoredBox(
          color: Colors.grey.shade200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _layer(BoxFit.cover, blurred: true),
              Positioned.fill(
                child: _layer(BoxFit.contain, blurred: false),
              ),
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
}
