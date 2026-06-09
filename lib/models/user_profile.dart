import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vouch/models/timestamp_converter.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String displayName,
    required String email,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime lastActiveAt,
    String? photoUrl,
    @Default('free') String membershipTier,
    @Default([]) List<String> savedRestaurantIds,
    @Default([]) List<String> blockedUserIds,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
