import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simpletodo/models/journal_doc.dart';
import 'package:simpletodo/models/task_doc.dart';

/// Single on-disk Isar for the app (tasks + journals). Two separate `Isar.open`
/// calls with one schema each can trigger native "Collection id is invalid" errors.
const String _appIsarName = 'tasks_local';

Isar? _appIsar;

Future<Isar> ensureAppIsarOpen() async {
  final existing = _appIsar;
  if (existing != null && existing.isOpen) {
    return existing;
  }
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [TaskDocSchema, JournalDocSchema],
    directory: dir.path,
    name: _appIsarName,
  );
  _appIsar = isar;
  unawaited(_deleteOrphanJournalOnlyDb(dir.path));
  return isar;
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
  final i = _appIsar;
  _appIsar = null;
  if (i != null && i.isOpen) {
    await i.close(deleteFromDisk: true);
  }
}
