import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vouch/models/timestamp_converter.dart';

part 'suggestion.freezed.dart';
part 'suggestion.g.dart';

enum SuggestionType { newRestaurant, correction, newCity, general }

const int kDailySuggestionCap = 1;

@freezed
abstract class Suggestion with _$Suggestion {
  const factory Suggestion({
    required String id,
    required String userId,
    required SuggestionType type,
    required String text,
    @TimestampConverter() required DateTime createdAt,
    String? cityId,
    @Default('pending') String status,
  }) = _Suggestion;

  factory Suggestion.fromJson(Map<String, dynamic> json) =>
      _$SuggestionFromJson(json);
}
