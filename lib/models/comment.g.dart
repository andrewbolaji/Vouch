// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
  id: json['id'] as String,
  restaurantId: json['restaurantId'] as String,
  userId: json['userId'] as String,
  userName: json['userName'] as String,
  text: json['text'] as String,
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Object),
  parentId: json['parentId'] as String?,
  isInsider: json['isInsider'] as bool? ?? false,
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'restaurantId': instance.restaurantId,
  'userId': instance.userId,
  'userName': instance.userName,
  'text': instance.text,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'parentId': instance.parentId,
  'isInsider': instance.isInsider,
};
