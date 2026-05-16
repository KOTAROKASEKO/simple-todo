import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';
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

  bool _isVideoPath(String pathOrUrl) {
    final uri = Uri.tryParse(pathOrUrl);
    final path = (uri?.path ?? pathOrUrl).toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv');
  }

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

    Future<void> openMediaFullScreen(String pathOrUrl) async {
      final isVideo = _isVideoPath(pathOrUrl);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => isVideo
              ? _JournalVideoFullScreenPage(pathOrUrl: pathOrUrl)
              : _JournalImageFullScreenPage(pathOrUrl: pathOrUrl),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? const Color(0xFF93C5FD) : Colors.blue.shade700;

    final appBar = AppBar(
      flexibleSpace: const LiquidGlassAppBarBackground(),
      foregroundColor: scheme.onSurface,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        dateLabel,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
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
          icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.45),
                    ),
                  ),
                  child: SelectableText(
                    content.isEmpty ? 'No content' : content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: scheme.onSurface,
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
                          (mq.size.width - 40 - 10) /
                          2; // page padding + grid gap
                      // Only pass cache width (not height): both dimensions use
                      // ResizeImagePolicy.exact and distort the decoded bitmap.
                      final memW = (tileLogicalW * mq.devicePixelRatio)
                          .round()
                          .clamp(120, 900);
                      if (_isVideoPath(pathOrUrl)) {
                        return _JournalVideoThumbnail(
                          pathOrUrl: pathOrUrl,
                          onTap: () => openMediaFullScreen(pathOrUrl),
                        );
                      }
                      return _JournalPhotoThumbnail(
                        pathOrUrl: pathOrUrl,
                        memCacheWidth: memW,
                        onTap: () => openMediaFullScreen(pathOrUrl),
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
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.04,
                          ),
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
                          iconColor: isDark
                              ? Colors.indigo.shade200
                              : Colors.indigo.shade700,
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
                                color: scheme.onSurface,
                              ),
                              h1: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: scheme.onSurface,
                              ),
                              h2: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: scheme.onSurface,
                              ),
                              h3: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                                color: scheme.onSurface,
                              ),
                              listBullet: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: scheme.onSurface,
                              ),
                              listIndent: 24,
                              blockSpacing: 10,
                              code: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                fontFamily: 'monospace',
                                color: scheme.onSurface,
                                backgroundColor: scheme.surfaceContainerHigh,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              blockquote: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              blockquotePadding: const EdgeInsets.only(
                                left: 12,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: scheme.outline,
                                    width: 3,
                                  ),
                                ),
                              ),
                              a: TextStyle(
                                color: linkColor,
                                decoration: TextDecoration.underline,
                              ),
                              strong: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              em: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      child: Transform.scale(scale: 1.12, child: core),
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

class _JournalVideoThumbnail extends StatelessWidget {
  const _JournalVideoThumbnail({required this.pathOrUrl, required this.onTap});

  final String pathOrUrl;
  final VoidCallback onTap;

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
            color: Colors.black87,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 28,
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalVideoFullScreenPage extends StatefulWidget {
  const _JournalVideoFullScreenPage({required this.pathOrUrl});

  final String pathOrUrl;

  @override
  State<_JournalVideoFullScreenPage> createState() =>
      _JournalVideoFullScreenPageState();
}

class _JournalVideoFullScreenPageState
    extends State<_JournalVideoFullScreenPage> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initVideo());
  }

  Future<void> _initVideo() async {
    final controller = journalImageIsNetworkUrl(widget.pathOrUrl)
        ? VideoPlayerController.networkUrl(Uri.parse(widget.pathOrUrl))
        : VideoPlayerController.file(File(widget.pathOrUrl));
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _ready = true;
    });
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: !_ready || controller == null
            ? const CircularProgressIndicator(color: Colors.white70)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  const SizedBox(height: 16),
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        if (controller.value.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      });
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
