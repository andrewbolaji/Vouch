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
    // Maintained by the onVoteCreated/onVoteDeleted triggers, never
    // by the client: firestore.rules denies client writes to this
    // field. Read once on sign-in so the app knows which vote
    // buttons to fill in without one read per restaurant.
    //
    // includeToJson: false so the model cannot carry a value into a
    // write. Without it, serializing a profile emits whatever the
    // model holds, which for a freshly constructed one is the []
    // default, and a write carrying that against a server list the
    // user really has is denied. Read side left alone: fromJson
    // still parses it.
    //
    // This makes the model incapable of forging the field. It does
    // not make a whole-document overwrite legal on a profile that
    // has votes: omitting the field from a non-merge set deletes the
    // server's list, which the rule denies too, and correctly.
    // Whole-document writes to users/{uid} are not a safe shape here
    // at all. Use named-field updates or set with merge.
    @JsonKey(includeToJson: false)
    @Default([])
    List<String> votedRestaurantIds,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
