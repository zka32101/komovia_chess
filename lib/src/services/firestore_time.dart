import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore stores `DateTime` fields as `Timestamp`, but every
/// komovia_core model round-trips `DateTime` via ISO8601 strings
/// (`DateTime.parse`) since komovia_core itself has no Firestore
/// dependency (see e.g. `Friendship`'s/`AppNotification`'s own doc
/// comments). Every Firestore-adapter file in this app needs the same
/// conversion at its read boundary, so it's shared here instead of
/// reimplemented per service.

/// Converts a raw Firestore field value (a `Timestamp`, an already-ISO8601
/// `String`, or `null`) into the ISO8601 string a komovia_core model's
/// `fromJson` expects.
String? isoFromTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value as String?;
}

/// Converts a raw Firestore field value into a `DateTime`, falling back to
/// [fallback] when the value isn't a `Timestamp` (e.g. missing).
DateTime dateTimeFromTimestamp(Object? value, DateTime fallback) {
  return value is Timestamp ? value.toDate() : fallback;
}

/// Same as [dateTimeFromTimestamp], but returns `null` instead of a
/// fallback when the value isn't a `Timestamp`.
DateTime? dateTimeFromTimestampOrNull(Object? value) {
  return value is Timestamp ? value.toDate() : null;
}
