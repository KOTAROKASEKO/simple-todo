import 'package:cloud_firestore/cloud_firestore.dart';

bool isFirestoreFieldValueDelete(Object? v) =>
    v.toString().contains('FieldValue');

/// Converts [updateData] for [DocumentReference.update].
///
/// Firestore [set] with merge incorrectly merges each element of an array of
/// maps (e.g. checklist), so updates must use [update] for full field replace.
///
/// [doneByDate] and [checklistDoneByDate] are flattened to dotted paths so one
/// day's value merges into the existing map instead of replacing the whole map.
Map<String, dynamic> flattenFirestoreUpdateData(
  Map<String, dynamic> updateData,
) {
  final out = <String, dynamic>{};
  for (final e in updateData.entries) {
    final k = e.key;
    final v = e.value;
    if (k == 'doneByDate') {
      if (isFirestoreFieldValueDelete(v)) {
        out['doneByDate'] = FieldValue.delete();
      } else if (v is Map) {
        for (final de in v.entries) {
          out['doneByDate.${de.key}'] = de.value;
        }
      } else {
        out[k] = v;
      }
    } else if (k == 'checklistDoneByDate') {
      if (isFirestoreFieldValueDelete(v)) {
        out['checklistDoneByDate'] = FieldValue.delete();
      } else if (v is Map) {
        for (final de in v.entries) {
          out['checklistDoneByDate.${de.key}'] = de.value;
        }
      } else {
        out[k] = v;
      }
    } else {
      out[k] = v;
    }
  }
  return out;
}
