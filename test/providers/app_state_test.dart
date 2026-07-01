import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';

void main() {
  group('AppState', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('starts in loading state', () {
      final state = AppState(useFirebase: false);
      expect(state.isLoading, isTrue);
    });

    test('loads cities after initialization', () async {
      final state = AppState(useFirebase: false);

      // Wait for async load
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      expect(state.isLoading, isFalse);
      expect(state.cities, isNotEmpty);
      expect(state.restaurants, isNotEmpty);
    });

    test('restaurantsForCity returns sorted results', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      final houston = state.restaurantsForCity('houston');
      expect(houston, isNotEmpty);

      for (var i = 0; i < houston.length - 1; i++) {
        expect(
          houston[i].rank,
          lessThanOrEqualTo(houston[i + 1].rank),
        );
      }
    });

    test('restaurantById returns correct restaurant', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      final result = state.restaurantById('hou-1');
      expect(result, isNotNull);
      expect(result!.name, 'Mensho');
    });

    test('restaurantById returns null for invalid id', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      expect(state.restaurantById('invalid'), isNull);
    });

    test('toggleVote increments then decrements', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      final before = state.restaurantById('hou-1')!.voteCount;
      expect(state.hasVoted('hou-1'), isFalse);

      state.toggleVote('hou-1', userId: 'test-user');
      expect(state.hasVoted('hou-1'), isTrue);
      expect(
        state.restaurantById('hou-1')!.voteCount,
        before + 1,
      );

      state.toggleVote('hou-1', userId: 'test-user');
      expect(state.hasVoted('hou-1'), isFalse);
      expect(
        state.restaurantById('hou-1')!.voteCount,
        before,
      );
    });

    test('toggleVote ignores invalid restaurant id', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      // Should not throw
      state.toggleVote('nonexistent', userId: 'test-user');
      expect(state.hasVoted('nonexistent'), isFalse);
    });

    test('vote persistence round-trip', () async {
      SharedPreferences.setMockInitialValues({
        'voted_restaurant_ids': ['hou-1', 'nyc-1'],
      });

      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      expect(state.hasVoted('hou-1'), isTrue);
      expect(state.hasVoted('nyc-1'), isTrue);
      expect(state.hasVoted('hou-2'), isFalse);
    });

    test('setSearchQuery filters cities', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      final allCount = state.cities.length;
      state.setSearchQuery('Houston');
      expect(state.cities.length, lessThan(allCount));
      expect(state.cities.first.name, 'Houston');

      state.setSearchQuery(null);
      expect(state.cities.length, allCount);
    });

    test('search is case insensitive', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      state.setSearchQuery('houston');
      expect(state.cities, isNotEmpty);
      expect(state.cities.first.name, 'Houston');
    });

    test('search with no results returns empty', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      state.setSearchQuery('Tokyo');
      expect(state.cities, isEmpty);
    });

    test('addComment creates a new comment', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      final beforeCount =
          state.commentsForRestaurant('hou-1').length;

      state.addComment(
        restaurantId: 'hou-1',
        text: 'Test comment',
      );

      expect(
        state.commentsForRestaurant('hou-1').length,
        beforeCount + 1,
      );
    });

    test('addComment with parentId creates a reply', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      state.addComment(
        restaurantId: 'hou-1',
        text: 'A reply',
        parentId: 'c1',
      );

      final replies = state.repliesForComment('c1');
      expect(replies.last.text, 'A reply');
    });

    test('seed restaurant commentCount matches seed comment count', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      // hou-1 (Mensho) has 2 seed comments (c1, c2), including replies
      final hou1 = state.restaurantById('hou-1');
      expect(hou1, isNotNull);
      expect(hou1!.commentCount, 2);

      // nyc-1 (Peter Luger) has 1 seed comment (c3)
      final nyc1 = state.restaurantById('nyc-1');
      expect(nyc1, isNotNull);
      expect(nyc1!.commentCount, 1);

      // hou-2 (Cool Runnings) has 0 seed comments
      final hou2 = state.restaurantById('hou-2');
      expect(hou2, isNotNull);
      expect(hou2!.commentCount, 0);
    });

    test('refresh reloads data', () async {
      final state = AppState(useFirebase: false);
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      expect(state.isLoading, isFalse);
      final refreshFuture = state.refresh();
      expect(state.isLoading, isTrue);
      await refreshFuture;
      expect(state.isLoading, isFalse);
    });
  });
}
