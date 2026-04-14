/// Task/journal persistence: Isar + Firestore sync on native; Firestore-only stubs on web.
///
/// Uses `dart.library.io` (not [kIsWeb]) so the compiler never includes Isar on web.
export 'src/export_web.dart' if (dart.library.io) 'src/export_io.dart';
