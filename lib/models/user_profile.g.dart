// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  email: json['email'] as String,
  createdAt: const TimestampConverter().fromJson(json['createdAt'] as Object),
  lastActiveAt: const TimestampConverter().fromJson(
    json['lastActiveAt'] as Object,
  ),
  photoUrl: json['photoUrl'] as String?,
  membershipTier: json['membershipTier'] as String? ?? 'free',
  savedRestaurantIds:
      (json['savedRestaurantIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  blockedUserIds:
      (json['blockedUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'email': instance.email,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'lastActiveAt': const TimestampConverter().toJson(instance.lastActiveAt),
      'photoUrl': instance.photoUrl,
      'membershipTier': instance.membershipTier,
      'savedRestaurantIds': instance.savedRestaurantIds,
      'blockedUserIds': instance.blockedUserIds,
    };
