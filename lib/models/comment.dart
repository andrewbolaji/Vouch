import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vouch/models/timestamp_converter.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String restaurantId,
    required String userId,
    required String userName,
    required String text,
    @TimestampConverter() required DateTime createdAt,
    String? parentId,
    @Default(false) bool isInsider,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}
