// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Report _$ReportFromJson(Map<String, dynamic> json) => _Report(
  id: json['id'] as String,
  reporterUid: json['reporterUid'] as String,
  commentId: json['commentId'] as String,
  commentPath: json['commentPath'] as String,
  restaurantId: json['restaurantId'] as String,
  cityId: json['cityId'] as String,
  reason: $enumDecode(_$ReportReasonEnumMap, json['reason']),
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Object),
);

Map<String, dynamic> _$ReportToJson(_Report instance) => <String, dynamic>{
  'id': instance.id,
  'reporterUid': instance.reporterUid,
  'commentId': instance.commentId,
  'commentPath': instance.commentPath,
  'restaurantId': instance.restaurantId,
  'cityId': instance.cityId,
  'reason': _$ReportReasonEnumMap[instance.reason]!,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
};

const _$ReportReasonEnumMap = {
  ReportReason.spam: 'spam',
  ReportReason.harassment: 'harassment',
  ReportReason.inappropriate: 'inappropriate',
  ReportReason.other: 'other',
};
