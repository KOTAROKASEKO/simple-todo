final Set<String> _hiveBoxNames = <String>{};

void registerHiveBoxName(String name) {
  _hiveBoxNames.add(name);
}

Set<String> getRegisteredHiveBoxNames() => Set<String>.from(_hiveBoxNames);
