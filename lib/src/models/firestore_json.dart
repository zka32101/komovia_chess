import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts a Firestore document's data into plain JSON that the generated
/// `fromJson` constructors (json_serializable) can read.
///
/// Firestore returns date fields as [Timestamp], but the generated code reads a
/// `DateTime` from an ISO-8601 *string* and throws
/// `type 'Timestamp' is not a subtype of type 'String'` otherwise - which the
/// callers turned into "no data" (e.g. "no daily challenge today") by
/// swallowing the error. [Timestamp]s are converted to ISO-8601 strings,
/// recursively through nested maps and lists; everything else is unchanged.
Map<String, dynamic> firestoreDataToJson(Map<String, dynamic> data) =>
    data.map((key, value) => MapEntry(key, _convert(value)));

dynamic _convert(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is Map<String, dynamic>) return firestoreDataToJson(value);
  if (value is List) return value.map(_convert).toList();
  return value;
}
