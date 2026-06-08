import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Converts between Firestore [Timestamp] and Dart [DateTime].
///
/// When reading from Firestore, the value may arrive as a [Timestamp].
/// When reading from plain JSON (e.g. local cache), it may be an int
/// (milliseconds since epoch) or an ISO-8601 string.
class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object json) {
    if (json is Timestamp) {
      return json.toDate();
    }
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    if (json is String) {
      return DateTime.parse(json);
    }
    throw ArgumentError('Cannot convert $json to DateTime');
  }

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

/// Same as [TimestampConverter] but for nullable DateTime fields.
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    return const TimestampConverter().fromJson(json);
  }

  @override
  Object? toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
