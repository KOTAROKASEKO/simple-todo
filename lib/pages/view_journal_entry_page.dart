import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:simpletodo/journal_image_cache.dart';
import 'package:simpletodo/widgets/journal_ai_character_avatar.dart';
import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

/// Full-screen read-only view of a single journal/diary entry.
/// [initialAiReflection] is filled when the server sends surprise AI feedback (push).
class ViewJournalEntryPage extends StatelessWidget {
  const ViewJournalEntryPage({
    super.key,
    required this.content,
    required this.dateLabel,
    required this.onDelete,
    this.imagePaths,
    this.initialAiReflection,
  });

  final String content;
  final String dateLabel;
  final Future<void> Function() onDelete;

  /// List of image file paths (or download URLs in the future). Backward compat: can be null/empty.
  final List<String>? imagePaths;
  final Map<String, dynamic>? initialAiReflection;

  @override
  Widget build(BuildContext context) {
    final paths = imagePaths ?? const [];
    String? aiReplyText;
    final m = initialAiReflection;
    if (m != null) {
      String? pick(String key) {
        final v = m[key];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final affirmation =
          pick('affirmation') ?? pick('message') ?? pick('reflection');
      final advice = pick('advice') ?? pick('body');
      final parts = <String>[];
      if (affirmation != null && affirmation.isNotEmpty) {
        parts.add(affirmation);
      }
      if (advice != null && advice.isNotEmpty) {
        parts.add(advice);
      }
      if (parts.isNotEmpty) {
        aiReplyText = parts.join('\n\n');
      }
    }
    final hasAi = aiReplyText != null && aiReplyText.isNotEmpty;
    var aiCharacterId = 'default';
    if (m != null) {
      final c = m['character'];
      if (c is String && c.trim().isNotEmpty) {
        aiCharacterId = c.trim();
      }
    }

    Future<void> openImageFullScreen(String pathOrUrl) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _JournalImageFullScreenPage(pathOrUrl: pathOrUrl),
        ),
      );
    }

    final appBar = AppBar(
      flexibleSpace: const LiquidGlassAppBarBackground(),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        dateLabel,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: Colors.grey.shade700),
      actions: [
        IconButton(
          tooltip: 'Delete entry',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Delete journal entry?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                );
              },
            );
            if (confirmed != true) return;
            try {
              await onDelete();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete entry: $e')),
              );
            }
          },
          icon: const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: 8),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: appBar,
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + appBar.preferredSize.height,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF8F9FC)),
                  ),
                  child: SelectableText(
                    content.isEmpty ? 'No content' : content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                if (paths.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paths.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.2,
                        ),
                    itemBuilder: (context, index) {
                      final pathOrUrl = paths[index];
                      final mq = MediaQuery.of(context);
                      final tileLogicalW =
                          (mq.size.width - 40 - 10) / 2; // page padding + grid gap
                      // Only pass cache width (not height): both dimensions use
                      // ResizeImagePolicy.exact and distort the decoded bitmap.
                      final memW = (tileLogicalW * mq.devicePixelRatio)
                          .round()
                          .clamp(120, 900);
                      return _JournalPhotoThumbnail(
                        pathOrUrl: pathOrUrl,
                        memCacheWidth: memW,
                        onTap: () => openImageFullScreen(pathOrUrl),
                      );
                    },
                  ),
                ],
                if (hasAi) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        JournalAiCharacterAvatar(
                          characterId: aiCharacterId,
                          size: 44,
                          iconColor: Colors.indigo.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MarkdownBody(
                            data: aiReplyText,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: Colors.grey.shade900,
                              ),
                              h1: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: Colors.grey.shade900,
                              ),
                              h2: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: Colors.grey.shade900,
                              ),
                              h3: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                                color: Colors.grey.shade900,
                              ),
                              listBullet: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: Colors.grey.shade900,
                              ),
                              listIndent: 24,
                              blockSpacing: 10,
                              code: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                fontFamily: 'monospace',
                                color: Colors.grey.shade800,
                                backgroundColor: Colors.grey.shade100,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              blockquote: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: Colors.grey.shade800,
                                fontStyle: FontStyle.italic,
                              ),
                              blockquotePadding: const EdgeInsets.only(
                                left: 12,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 3,
                                  ),
                                ),
                              ),
                              a: TextStyle(
                                color: Colors.blue.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              strong: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                              em: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail: [BoxFit.contain] foreground + blurred same image ([BoxFit.cover]) filling letterbox.
class _JournalPhotoThumbnail extends StatelessWidget {
  const _JournalPhotoThumbnail({
    required this.pathOrUrl,
    required this.memCacheWidth,
    required this.onTap,
  });

  final String pathOrUrl;
  /// Decode cap for network images; height omitted so decode keeps aspect ratio.
  final int memCacheWidth;
  final VoidCallback onTap;

  static const double _blurSigma = 14;

  Widget _networkImage(BoxFit fit) {
    return CachedNetworkImage(
      imageUrl: pathOrUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) => Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey.shade500,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _fileImage(BoxFit fit) {
    return Image.file(
      File(pathOrUrl),
      fit: fit,
      errorBuilder: (context, error, _) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _layer(BoxFit fit, {required bool blurred}) {
    final core = journalImageIsNetworkUrl(pathOrUrl)
        ? _networkImage(fit)
        : _fileImage(fit);
    if (!blurred) {
      return core;
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
      child: Transform.scale(
        scale: 1.12,
        child: core,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
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
      ),
    );
  }
}

class _JournalImageFullScreenPage extends StatelessWidget {
  const _JournalImageFullScreenPage({required this.pathOrUrl});

  final String pathOrUrl;

  Widget _network(BoxFit fit, {Widget? placeholder}) {
    return CachedNetworkImage(
      imageUrl: pathOrUrl,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white70,
        size: 40,
      ),
    );
  }

  Widget _file(BoxFit fit) {
    return Image.file(
      File(pathOrUrl),
      fit: fit,
      errorBuilder: (context, error, _) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white70,
        size: 40,
      ),
    );
  }

  Widget _image(BoxFit fit, {Widget? placeholder}) {
    return journalImageIsNetworkUrl(pathOrUrl)
        ? _network(fit, placeholder: placeholder)
        : _file(fit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: SizedBox(
                width: w,
                height: h,
                child: _image(
                  BoxFit.contain,
                  placeholder: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
