import 'dart:async';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'journal_doc.dart';
import 'task_doc.dart';

/// Single on-disk Isar for the app (tasks + journals). Two separate `Isar.open`
/// calls with one schema each can trigger native "Collection id is invalid" errors.
///
/// Bumped from `tasks_local` so installs with an incompatible on-disk schema get a
/// clean file; task/journal data is re-synced from Firestore.
const String _appIsarName = 'tasks_local_v2';

Isar? _appIsar;
Future<Isar>? _ensureInFlight;

/// Pre-v2 filenames (schema drift / corrupt DB); remove so they never get opened again.
Future<void> _deleteLegacyPreV2Files(String dirPath) async {
  for (final name in ['tasks_local.isar', 'tasks_local.isar.lock']) {
    try {
      final f = File('$dirPath/$name');
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }
}

Future<void> _deleteAppIsarDatabaseFiles(String dirPath) async {
  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return;
    }
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final path = entity.path;
      final sep = Platform.pathSeparator;
      final idx = path.lastIndexOf(sep);
      final base = idx >= 0 ? path.substring(idx + 1) : path;
      final isOurDb = base.startsWith(_appIsarName) &&
          (base.endsWith('.isar') || base.endsWith('.lock'));
      if (!isOurDb) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

bool _isIsarSchemaOpenError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('collection id') && s.contains('invalid');
}

Future<void> _closeRegisteredAppIsarIfOpen({required bool deleteFromDisk}) async {
  final hung = Isar.getInstance(_appIsarName);
  if (hung != null && hung.isOpen) {
    try {
      await hung.close(deleteFromDisk: deleteFromDisk);
    } catch (_) {}
  }
  _appIsar = null;
}

Future<Isar> _openAppIsarOnce() async {
  final dir = await getApplicationDocumentsDirectory();
  await _deleteLegacyPreV2Files(dir.path);

  Future<Isar> open() => Isar.open(
        [TaskDocSchema, JournalDocSchema],
        directory: dir.path,
        name: _appIsarName,
      );

  // Registry can still hold an instance after a failed open; reuse or close before reopen.
  final registered = Isar.getInstance(_appIsarName);
  if (registered != null && registered.isOpen) {
    _appIsar = registered;
    unawaited(_deleteOrphanJournalOnlyDb(dir.path));
    return registered;
  }

  try {
    final isar = await open();
    _appIsar = isar;
    unawaited(_deleteOrphanJournalOnlyDb(dir.path));
    return isar;
  } catch (e) {
    if (!_isIsarSchemaOpenError(e)) {
      rethrow;
    }
    // Stale native handle and/or corrupt files: close, wipe v2 + legacy names, retry.
    for (var attempt = 0; attempt < 3; attempt++) {
      await _closeRegisteredAppIsarIfOpen(deleteFromDisk: true);
      await _deleteAppIsarDatabaseFiles(dir.path);
      await _deleteLegacyPreV2Files(dir.path);
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      try {
        final isar = await open();
        _appIsar = isar;
        unawaited(_deleteOrphanJournalOnlyDb(dir.path));
        return isar;
      } catch (e2) {
        if (!_isIsarSchemaOpenError(e2) || attempt == 2) {
          rethrow;
        }
      }
    }
    throw StateError('Isar.open retries exhausted');
  }
}

Future<Isar> ensureAppIsarOpen() async {
  final existing = _appIsar;
  if (existing != null && existing.isOpen) {
    return existing;
  }

  final registered = Isar.getInstance(_appIsarName);
  if (registered != null && registered.isOpen) {
    _appIsar = registered;
    return registered;
  }

  _ensureInFlight ??= _openAppIsarOnce();
  try {
    return await _ensureInFlight!;
  } finally {
    _ensureInFlight = null;
  }
}

/// Removes the old standalone journal DB (no longer used).
Future<void> _deleteOrphanJournalOnlyDb(String dirPath) async {
  try {
    final f = File('$dirPath/journal_local.isar');
    if (await f.exists()) {
      await f.delete();
    }
  } catch (_) {}
}

Future<void> clearAppIsarOnLogout() async {
  _ensureInFlight = null;
  final i = _appIsar;
  _appIsar = null;
  if (i != null && i.isOpen) {
    await i.close(deleteFromDisk: true);
  }
}
