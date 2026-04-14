import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

bool journalImageIsNetworkUrl(String ref) =>
    ref.startsWith('http://') || ref.startsWith('https://');

/// Writes network journal photos to the same disk store [CachedNetworkImage] uses,
/// so reopening an entry is fast (no full re-download).
Future<void> warmJournalImageDiskCache(Iterable<String> urls) async {
  for (final u in urls) {
    final s = u.trim();
    if (!journalImageIsNetworkUrl(s)) continue;
    try {
      await DefaultCacheManager().downloadFile(s);
    } catch (_) {}
  }
}

/// Warms Flutter's in-memory image cache (decoded bitmaps) when [context] is mounted.
Future<void> warmJournalImageMemoryCache(
  BuildContext context,
  Iterable<String> urls,
) async {
  if (!context.mounted) return;
  for (final u in urls) {
    final s = u.trim();
    if (!journalImageIsNetworkUrl(s)) continue;
    try {
      await precacheImage(CachedNetworkImageProvider(s), context);
    } catch (_) {}
  }
}
