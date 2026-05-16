# localdb switch

Use these files with `--dart-define-from-file` so local DB mode is explicit.

## Run

- Hive:
  `flutter run --flavor hive --dart-define-from-file=config/localdb/hive.json`
- Isar:
  `flutter run --flavor isar --dart-define-from-file=config/localdb/isar.json`
- ObjectBox:
  `flutter run --flavor objectBox --dart-define-from-file=config/localdb/objectBox.json`

## Release aab build
  - Hive:
  `flutter build aab --release --flavor hive --dart-define-from-file=config/localdb/hive.json`
- Isar:
  `flutter build aab --release --flavor isar --dart-define-from-file=config/localdb/isar.json`
- ObjectBox:
  `flutter build aab --release --flavor objectBox --dart-define-from-file=config/localdb/objectBox.json`
