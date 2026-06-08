// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Suggestion _$SuggestionFromJson(Map<String, dynamic> json) => _Suggestion(
  id: json['id'] as String,
  userId: json['userId'] as String,
  type: $enumDecode(_$SuggestionTypeEnumMap, json['type']),
  text: json['text'] as String,
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Object),
  cityId: json['cityId'] as String?,
  status: json['status'] as String? ?? 'pending',
);

Map<String, dynamic> _$SuggestionToJson(_Suggestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': _$SuggestionTypeEnumMap[instance.type]!,
      'text': instance.text,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'cityId': instance.cityId,
      'status': instance.status,
    };

const _$SuggestionTypeEnumMap = {
  SuggestionType.newRestaurant: 'newRestaurant',
  SuggestionType.correction: 'correction',
  SuggestionType.newCity: 'newCity',
  SuggestionType.general: 'general',
};
