import 'package:objectbox/objectbox.dart';

/// Single Key–JSON-value row for local task and journal data.
@Entity()
class ObKv {
  /// ObjectBox id (auto).
  int id = 0;

  /// Key: `t:docId`, `o:opId`, `j:docId`, or `jo:opId` depending on the store.
  @Unique()
  @Index()
  String k = '';

  /// JSON-encoded value (Map as JSON).
  String v = '{}';
}
