import 'package:flutter/material.dart';
import 'dart:io';

import 'package:simpletodo/widgets/liquid_glass_app_bar.dart';

bool _journalImageIsNetworkUrl(String ref) =>
    ref.startsWith('http://') || ref.startsWith('https://');

/// Full-screen read-only view of a single journal/diary entry.
class ViewJournalEntryPage extends StatelessWidget {
  const ViewJournalEntryPage({
    super.key,
    required this.content,
    required this.dateLabel,
    required this.onDelete,
    this.imagePaths,
  });

  final String content;
  final String dateLabel;
  final Future<void> Function() onDelete;
  /// List of image file paths (or download URLs in the future). Backward compat: can be null/empty.
  final List<String>? imagePaths;

  @override
  Widget build(BuildContext context) {
    final paths = imagePaths ?? const [];
    Future<void> openImageFullScreen(String pathOrUrl) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) {
            final image = _journalImageIsNetworkUrl(pathOrUrl)
                ? Image.network(
                    pathOrUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, __) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 40,
                    ),
                  )
                : Image.file(
                    File(pathOrUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, __) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 40,
                    ),
                  );
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: SafeArea(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: image,
                  ),
                ),
              ),
            );
          },
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
                      final tileImage = _journalImageIsNetworkUrl(pathOrUrl)
                          ? Image.network(
                              pathOrUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : Image.file(
                              File(pathOrUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => openImageFullScreen(pathOrUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              color: Colors.grey.shade200,
                              child: tileImage,
                            ),
                          ),
                        ),
                      );
                    },
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
