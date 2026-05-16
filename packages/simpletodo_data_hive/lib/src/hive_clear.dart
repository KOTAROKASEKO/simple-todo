import 'package:hive/hive.dart';
import 'hive_box_registry.dart';

Future<void> clearAppHiveOnLogout() async {
  final names = <String>{
    ...getRegisteredHiveBoxNames(),
    'tasks',
    'task_order',
  };
  for (final name in names) {
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).close();
      }
    } catch (_) {}
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
  }
}
