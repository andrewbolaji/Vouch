import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/core/utils/block_filter.dart';
import 'package:vouch/models/comment.dart';

/// Tests for the production [filterBlockedComments] function.
///
/// Both this test and the restaurant detail screen import and call
/// the same function from lib/core/utils/block_filter.dart.
/// If the production logic changes, these tests break.

void main() {
  final now = DateTime(2026, 6, 9);

  final commentA = Comment(
    id: 'c1',
    restaurantId: 'hou-1',
    userId: 'user-a',
    userName: 'Alice',
    text: 'Great food!',
    createdAt: now,
  );

  final commentB = Comment(
    id: 'c2',
    restaurantId: 'hou-1',
    userId: 'user-b',
    userName: 'Bob',
    text: 'Not my favorite.',
    createdAt: now,
  );

  final commentC = Comment(
    id: 'c3',
    restaurantId: 'hou-1',
    userId: 'user-c',
    userName: 'Charlie',
    text: 'Amazing place!',
    createdAt: now,
  );

  group('filterBlockedComments', () {
    test('blocked user comments are excluded', () {
      final result = filterBlockedComments(
        [commentA, commentB, commentC],
        {'user-b'},
      );
      expect(result, hasLength(2));
      expect(result.map((c) => c.userId), ['user-a', 'user-c']);
    });

    test('empty blocklist returns all comments', () {
      final result = filterBlockedComments(
        [commentA, commentB, commentC],
        {},
      );
      expect(result, hasLength(3));
    });

    test('blocking all users returns empty list', () {
      final result = filterBlockedComments(
        [commentA, commentB, commentC],
        {'user-a', 'user-b', 'user-c'},
      );
      expect(result, isEmpty);
    });

    test('unblocking restores visibility', () {
      final blocked = {'user-b'};
      expect(
        filterBlockedComments([commentA, commentB, commentC], blocked),
        hasLength(2),
      );

      blocked.remove('user-b');
      final restored = filterBlockedComments(
        [commentA, commentB, commentC],
        blocked,
      );
      expect(restored, hasLength(3));
      expect(restored.map((c) => c.userId), ['user-a', 'user-b', 'user-c']);
    });

    test('block does not affect other users', () {
      final result = filterBlockedComments(
        [commentA, commentB, commentC],
        {'user-b'},
      );
      expect(result.any((c) => c.userId == 'user-a'), isTrue);
      expect(result.any((c) => c.userId == 'user-c'), isTrue);
      expect(result.any((c) => c.userId == 'user-b'), isFalse);
    });
  });
}
