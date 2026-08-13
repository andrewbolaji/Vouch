// votedRestaurantIds is trigger-owned. firestore.rules denies any
// client write that changes it, so the model must not be able to
// carry a value into one.
//
// The hazard is specific: a client that loads a profile, edits one
// field and writes the whole document back would send whatever
// votedRestaurantIds the model happened to hold. A freshly
// constructed model holds the [] default, which differs from a real
// server list, and the write is denied. That breaks only for users
// who have actually voted, and passes every test run with a fresh
// account, which is exactly the kind of bug that reaches production.

import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/user_profile.dart';

void main() {
  UserProfile profile({List<String> voted = const []}) => UserProfile(
        id: 'alice',
        displayName: 'Alice',
        email: 'alice@example.com',
        createdAt: DateTime(2026),
        lastActiveAt: DateTime(2026),
        votedRestaurantIds: voted,
      );

  test('toJson never emits votedRestaurantIds', () {
    expect(
      profile().toJson().containsKey('votedRestaurantIds'),
      isFalse,
      reason: 'the client must not be able to serialize a field it is '
          'not allowed to write',
    );
  });

  test('toJson omits it even when the model holds a real list', () {
    expect(
      profile(voted: ['hou-1', 'hou-2'])
          .toJson()
          .containsKey('votedRestaurantIds'),
      isFalse,
    );
  });

  test('the rest of the profile still serializes', () {
    final json = profile().toJson();
    expect(json['id'], 'alice');
    expect(json['displayName'], 'Alice');
    expect(json['email'], 'alice@example.com');
    expect(json['savedRestaurantIds'], isEmpty);
    expect(json['blockedUserIds'], isEmpty);
  });

  // Read-only, not invisible: reconciliation reads the field from the
  // raw document, but anything going through the model still needs to
  // see it.
  test('fromJson still reads votedRestaurantIds', () {
    final parsed = UserProfile.fromJson({
      'id': 'alice',
      'displayName': 'Alice',
      'email': 'alice@example.com',
      'createdAt': DateTime(2026).toIso8601String(),
      'lastActiveAt': DateTime(2026).toIso8601String(),
      'votedRestaurantIds': ['hou-1'],
    });

    expect(parsed.votedRestaurantIds, ['hou-1']);
  });
}
