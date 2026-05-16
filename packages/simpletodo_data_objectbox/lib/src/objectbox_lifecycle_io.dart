import 'dart:io';

import 'package:objectbox/objectbox.dart';

/// Keeps [Store] references so logout can [Store.close] before deleting files.
final List<Store> _openStores = <Store>[];
final Set<String> _registerPaths = <String>{};

void registerObjectBoxDataPath(String absolutePath) {
  _registerPaths.add(absolutePath);
}

void registerObjectBoxStore(Store store) {
  if (!_openStores.contains(store)) {
    _openStores.add(store);
  }
}

void unregisterObjectBoxStore(Store store) {
  _openStores.remove(store);
}

Future<void> clearAppObjectBoxOnLogout() async {
  for (final s in List<Store>.from(_openStores)) {
    try {
      s.close();
    } catch (_) {}
  }
  _openStores.clear();
  for (final p in _registerPaths) {
    try {
      if (Directory(p).existsSync()) {
        await Directory(p).delete(recursive: true);
      }
    } catch (_) {}
  }
  _registerPaths.clear();
}
