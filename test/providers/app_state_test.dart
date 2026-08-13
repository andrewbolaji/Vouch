import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/repositories/city_repository.dart';
import 'package:vouch/repositories/comment_repository.dart';
import 'package:vouch/repositories/restaurant_repository.dart';
import 'package:vouch/repositories/vote_repository.dart';
import 'package:vouch/services/auth_service.dart';

/// Stands in for FirebaseAuth in CommentRepository test doubles that
/// only exercise getPage/getReplies/submitComment overrides and never
/// touch FirebaseAuth themselves. Its only job is to let the base
/// constructor run without FirebaseAuth.instance, which requires a
/// real initialized Firebase app.
class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Stub CityRepository that returns a fixed list without Firestore.
class StubCityRepository extends CityRepository {
  StubCityRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<City>> getCities() async => [
        const City(
          id: 'test-city',
          name: 'Test City',
          state: 'TX',
          imageUrl: '',
          description: '',
        ),
      ];
}

/// Spy RestaurantRepository that records canViewTop10 arguments.
class SpyRestaurantRepository extends RestaurantRepository {
  SpyRestaurantRepository() : super(firestore: FakeFirebaseFirestore());

  final List<bool> canViewTop10Calls = [];

  @override
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async {
    canViewTop10Calls.add(canViewTop10);
    return [];
  }
}

/// Stub RestaurantRepository that returns one fixed restaurant, for
/// testing the online comment read path against a real restaurantId.
class StubRestaurantRepository extends RestaurantRepository {
  StubRestaurantRepository(this.restaurant)
      : super(firestore: FakeFirebaseFirestore());

  final Restaurant restaurant;

  @override
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async =>
      [restaurant];
}

/// Wraps a real, FakeFirebaseFirestore-backed CommentRepository and
/// counts getPage calls, so a test can assert a re-entered screen did
/// not refetch an already-loaded page.
class CountingCommentRepository extends CommentRepository {
  CountingCommentRepository(this._firestore)
      : super(firestore: _firestore, auth: _FakeFirebaseAuth());

  final FirebaseFirestore _firestore;
  int getPageCallCount = 0;

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) {
    getPageCallCount++;
    return CommentRepository(
      firestore: _firestore,
      auth: _FakeFirebaseAuth(),
    ).getPage(
      restaurantId,
      cursor: cursor,
      pageSize: pageSize,
    );
  }
}

/// CommentRepository whose getPage always fails, for testing the
/// error state.
class ThrowingCommentRepository extends CommentRepository {
  ThrowingCommentRepository()
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _FakeFirebaseAuth(),
        );

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) =>
      throw Exception('Simulated network failure');
}

/// CommentRepository that returns pre-programmed pages in sequence
/// and records the cursor it was called with each time. Used instead
/// of a real cursor round-trip against FakeFirebaseFirestore, whose
/// startAfterDocument does not return a second page for this query
/// shape (where + orderBy + limit): the point of this fake is to
/// verify AppState's pagination orchestration (does it pass the
/// previous nextCursor forward, does it stop when nextCursor is
/// null), not to re-prove Firestore's own cursor semantics.
class SequencedCommentRepository extends CommentRepository {
  SequencedCommentRepository(this._pages)
      : super(
          firestore: FakeFirebaseFirestore(),
          auth: _FakeFirebaseAuth(),
        );

  final List<({List<Comment> comments, String? nextCursor})> _pages;
  final List<String?> cursorsReceived = [];

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) async {
    cursorsReceived.add(cursor);
    return _pages[cursorsReceived.length - 1];
  }

  @override
  Future<List<Comment>> getReplies(
    String restaurantId,
    String commentId,
  ) async =>
      const [];
}

/// CommentRepository whose submitComment returns a synthetic Comment
/// instead of calling the real submitComment Cloud Function, for
/// testing AppState.addComment's online path without a network call.
class FakeSubmitCommentRepository extends CommentRepository {
  FakeSubmitCommentRepository({FirebaseFirestore? firestore})
      : super(
          firestore: firestore ?? FakeFirebaseFirestore(),
          auth: _FakeFirebaseAuth(),
        );

  @override
  Future<Comment> submitComment({
    required String restaurantId,
    required String text,
    String? parentId,
  }) async =>
      Comment(
        id: 'server-generated-id',
        restaurantId: restaurantId,
        userId: 'user1',
        userName: 'Alice',
        text: text,
        createdAt: DateTime(2026),
        parentId: parentId,
      );
}

/// VoteRepository whose vote/unvote always fail, for testing that
/// toggleVote rolls its optimistic update back on a real write
/// failure.
class ThrowingVoteRepository extends VoteRepository {
  ThrowingVoteRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> vote(String restaurantId, String userId) =>
      throw Exception('Simulated network failure');

  @override
  Future<void> unvote(String restaurantId, String userId) =>
      throw Exception('Simulated network failure');
}

/// VoteRepository backed by a fixed, pre-programmed set of voted
/// restaurant IDs, for testing AppState's server reconciliation on
/// sign-in without a real Firestore round trip. vote/unvote succeed
/// as no-ops; this double only needs to prove what AppState does
/// with hasVoted's answer, not exercise the write path.
class StubVoteRepository extends VoteRepository {
  StubVoteRepository(this._serverVotedIds)
      : super(firestore: FakeFirebaseFirestore());

  final Set<String> _serverVotedIds;
  final List<String> hasVotedCalls = [];

  @override
  Future<bool> hasVoted(String restaurantId, String userId) async {
    hasVotedCalls.add(restaurantId);
    return _serverVotedIds.contains(restaurantId);
  }

  @override
  Future<void> vote(String restaurantId, String userId) async {}

  @override
  Future<void> unvote(String restaurantId, String userId) async {}
}

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

      await state.toggleVote('hou-1', userId: 'test-user');
      expect(state.hasVoted('hou-1'), isTrue);
      expect(
        state.restaurantById('hou-1')!.voteCount,
        before + 1,
      );

      await state.toggleVote('hou-1', userId: 'test-user');
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
      await state.toggleVote('nonexistent', userId: 'test-user');
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
      expect(state.hasVoted('hou-11'), isFalse);
    });

    test(
        'toggleVote awaits the write and rolls back local state on '
        'failure', () async {
      const restaurant = Restaurant(
        id: 'hou-1',
        cityId: 'test-city',
        name: 'Mensho',
        cuisine: 'Ramen',
        imageUrl: '',
        description: '',
        rank: 1,
      );
      final state = AppState(
        useFirebase: true,
        cityRepo: StubCityRepository(),
        restaurantRepo: StubRestaurantRepository(restaurant),
        voteRepo: ThrowingVoteRepository(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final before = state.restaurantById('hou-1')!.voteCount;
      expect(state.hasVoted('hou-1'), isFalse);

      // Rethrows: the caller (the screen) is meant to catch this and
      // show it, the same contract addComment already has.
      await expectLater(
        state.toggleVote('hou-1', userId: 'test-user'),
        throwsException,
      );

      // Rolled back: a failed write must not leave the optimistic
      // flip in place.
      expect(state.hasVoted('hou-1'), isFalse);
      expect(state.restaurantById('hou-1')!.voteCount, before);
    });

    test(
        'toggleVote rolls back an unvote the same way when the delete '
        'fails', () async {
      SharedPreferences.setMockInitialValues({
        'voted_restaurant_ids': ['hou-1'],
      });
      const restaurant = Restaurant(
        id: 'hou-1',
        cityId: 'test-city',
        name: 'Mensho',
        cuisine: 'Ramen',
        imageUrl: '',
        description: '',
        rank: 1,
        voteCount: 10,
      );
      final state = AppState(
        useFirebase: true,
        cityRepo: StubCityRepository(),
        restaurantRepo: StubRestaurantRepository(restaurant),
        voteRepo: ThrowingVoteRepository(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(state.hasVoted('hou-1'), isTrue);
      final before = state.restaurantById('hou-1')!.voteCount;

      await expectLater(
        state.toggleVote('hou-1', userId: 'test-user'),
        throwsException,
      );

      expect(state.hasVoted('hou-1'), isTrue);
      expect(state.restaurantById('hou-1')!.voteCount, before);
    });

    test(
        'reconciles local votes against the server when a user signs '
        'in', () async {
      const restaurantA = Restaurant(
        id: 'hou-1',
        cityId: 'test-city',
        name: 'Mensho',
        cuisine: 'Ramen',
        imageUrl: '',
        description: '',
        rank: 1,
      );
      // Local state (e.g. left over from a previous, different
      // signed-in user on this device) claims hou-1 is voted. The
      // server disagrees: it has no vote for this user at all. A new
      // device / new sign-in must end up matching the server, not
      // keeping whatever was here before.
      SharedPreferences.setMockInitialValues({
        'voted_restaurant_ids': ['hou-1'],
      });
      final auth = AuthService.mock();
      final voteRepo = StubVoteRepository({});
      final state = AppState(
        useFirebase: true,
        cityRepo: StubCityRepository(),
        restaurantRepo: StubRestaurantRepository(restaurantA),
        voteRepo: voteRepo,
        authService: auth,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Confirms local state before reconciliation, so the assertion
      // below is proven to be a real change, not a coincidence.
      expect(state.hasVoted('hou-1'), isTrue);

      auth.setMockUser(
        const AuthUser(uid: 'real-user', emailVerified: true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(voteRepo.hasVotedCalls, contains('hou-1'));
      expect(state.hasVoted('hou-1'), isFalse);
    });

    test(
        'reconciles from the server on cold start when already signed '
        'in', () async {
      const restaurant = Restaurant(
        id: 'hou-1',
        cityId: 'test-city',
        name: 'Mensho',
        cuisine: 'Ramen',
        imageUrl: '',
        description: '',
        rank: 1,
      );
      final auth = AuthService.mock(
        initialUser: const AuthUser(uid: 'real-user', emailVerified: true),
      );
      final voteRepo = StubVoteRepository({'hou-1'});
      final state = AppState(
        useFirebase: true,
        cityRepo: StubCityRepository(),
        restaurantRepo: StubRestaurantRepository(restaurant),
        voteRepo: voteRepo,
        authService: auth,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(voteRepo.hasVotedCalls, contains('hou-1'));
      expect(state.hasVoted('hou-1'), isTrue);
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

      await state.addComment(
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

      await state.addComment(
        restaurantId: 'hou-1',
        text: 'A reply',
        parentId: 'c1',
      );

      final replies = state.repliesForComment('c1', restaurantId: 'hou-1');
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

      // hou-11 (Tacos Los Brothers) has 0 seed comments
      final hou11 = state.restaurantById('hou-11');
      expect(hou11, isNotNull);
      expect(hou11!.commentCount, 0);
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

  group('AppState paid-tier reload wiring', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'membership change free to paid reloads '
      'with canViewTop10 true',
      () async {
        final spyRepo = SpyRestaurantRepository();
        final membership = MembershipProvider();
        // ignore: unused_local_variable, keeps AppState alive
        final state = AppState(
          useFirebase: true,
          cityRepo: StubCityRepository(),
          restaurantRepo: spyRepo,
          membershipProvider: membership,
        );

        // Wait for initial load
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(spyRepo.canViewTop10Calls, [false]);

        // Simulate paid purchase via direct tier set
        membership.setTierForTest(MembershipTier.localsPass);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(spyRepo.canViewTop10Calls, [false, true]);
      },
    );

    test(
      'membership change paid to free reloads '
      'with canViewTop10 false',
      () async {
        final spyRepo = SpyRestaurantRepository();
        final membership = MembershipProvider(
          initialTier: MembershipTier.localsPass,
        );
        // ignore: unused_local_variable, keeps AppState alive
        final state = AppState(
          useFirebase: true,
          cityRepo: StubCityRepository(),
          restaurantRepo: spyRepo,
          membershipProvider: membership,
          isPaidTier: true,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(spyRepo.canViewTop10Calls, [true]);

        membership.setTierForTest(MembershipTier.free);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(spyRepo.canViewTop10Calls, [true, false]);
      },
    );

    test(
      'no reload when tier unchanged '
      '(billing cycle toggle)',
      () async {
        final spyRepo = SpyRestaurantRepository();
        final membership = MembershipProvider();
        // ignore: unused_local_variable, keeps AppState alive
        final state = AppState(
          useFirebase: true,
          cityRepo: StubCityRepository(),
          restaurantRepo: spyRepo,
          membershipProvider: membership,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(spyRepo.canViewTop10Calls, [false]);

        // toggleBillingCycle calls notifyListeners but
        // does not change canViewTop10
        membership.toggleBillingCycle();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Still only one call (the initial load)
        expect(spyRepo.canViewTop10Calls, [false]);
      },
    );

    test(
      'no duplicate load on first construction',
      () async {
        final spyRepo = SpyRestaurantRepository();
        final membership = MembershipProvider();
        AppState(
          useFirebase: true,
          cityRepo: StubCityRepository(),
          restaurantRepo: spyRepo,
          membershipProvider: membership,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Exactly one load from construction, not two
        expect(spyRepo.canViewTop10Calls, [false]);
      },
    );

    test(
      'sign-out resets membership to free and '
      'triggers reload with canViewTop10 false',
      () async {
        final spyRepo = SpyRestaurantRepository();
        final auth = AuthService.mock(
          initialUser: const AuthUser(
            uid: 'u1',
            email: 'a@b.com',
            method: AuthMethod.email,
          ),
        );
        final membership = MembershipProvider(
          initialTier: MembershipTier.localsPass,
          authService: auth,
        );
        // ignore: unused_local_variable, keeps AppState alive
        final state = AppState(
          useFirebase: true,
          cityRepo: StubCityRepository(),
          restaurantRepo: spyRepo,
          membershipProvider: membership,
          isPaidTier: true,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(spyRepo.canViewTop10Calls, [true]);

        // Simulate sign-out
        auth.setMockUser(null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(membership.canViewTop10, isFalse);
        expect(spyRepo.canViewTop10Calls, [true, false]);
      },
    );
  });

  group('AppState online comment loading', () {
    late FakeFirebaseFirestore fakeFirestore;

    const restaurant = Restaurant(
      id: 'online-r1',
      cityId: 'test-city',
      name: 'Online Test Restaurant',
      cuisine: 'Test',
      imageUrl: '',
      description: '',
      rank: 1,
      commentCount: 5,
    );

    CollectionReference<Map<String, dynamic>> commentsRef() => fakeFirestore
        .collection('restaurants')
        .doc(restaurant.id)
        .collection('comments');

    Future<void> seedComment(
      String id, {
      required String text,
      required DateTime createdAt,
      String? parentId,
    }) async {
      await commentsRef().doc(id).set({
        'userId': 'user-$id',
        'userName': 'User $id',
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        'parentId': parentId,
        'isInsider': false,
      });
    }

    AppState buildState({CommentRepository? commentRepo}) {
      return AppState(
        useFirebase: true,
        cityRepo: StubCityRepository(),
        restaurantRepo: StubRestaurantRepository(restaurant),
        commentRepo:
            commentRepo ??
                CommentRepository(
                  firestore: fakeFirestore,
                  auth: _FakeFirebaseAuth(),
                ),
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'loadCommentsForRestaurant transitions notLoaded -> loading -> loaded',
      () async {
        await seedComment(
          'c1',
          text: 'First',
          createdAt: DateTime(2026),
        );
        final state = buildState();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          state.commentsStatus('online-r1'),
          CommentLoadStatus.notLoaded,
        );

        final future = state.loadCommentsForRestaurant('online-r1');
        expect(state.commentsStatus('online-r1'), CommentLoadStatus.loading);

        await future;
        expect(state.commentsStatus('online-r1'), CommentLoadStatus.loaded);
        expect(state.commentsForRestaurant('online-r1'), hasLength(1));
      },
    );

    test(
      'loadCommentsForRestaurant does not refetch once already loaded',
      () async {
        await seedComment(
          'c1',
          text: 'First',
          createdAt: DateTime(2026),
        );
        final countingRepo = CountingCommentRepository(fakeFirestore);
        final state = buildState(commentRepo: countingRepo);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await state.loadCommentsForRestaurant('online-r1');
        await state.loadCommentsForRestaurant('online-r1');
        await state.loadCommentsForRestaurant('online-r1');

        expect(countingRepo.getPageCallCount, 1);
      },
    );

    test(
      'loadCommentsForRestaurant sets status error on failure',
      () async {
        final state = buildState(commentRepo: ThrowingCommentRepository());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await state.loadCommentsForRestaurant('online-r1');

        expect(state.commentsStatus('online-r1'), CommentLoadStatus.error);
        expect(state.commentsError('online-r1'), isNotNull);
      },
    );

    test(
      'loadMoreComments appends next page and clears cursor when exhausted',
      () async {
        Comment fakeComment(String id, String text) => Comment(
              id: id,
              restaurantId: 'online-r1',
              userId: 'u-$id',
              userName: 'User $id',
              text: text,
              createdAt: DateTime(2026),
            );

        final repo = SequencedCommentRepository([
          (
            comments: [
              fakeComment('p1-a', 'Page 1 comment A'),
              fakeComment('p1-b', 'Page 1 comment B'),
            ],
            nextCursor: 'cursor-after-page-1',
          ),
          (
            comments: [fakeComment('p2-a', 'Page 2 comment A')],
            nextCursor: null,
          ),
        ]);
        final state = buildState(commentRepo: repo);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await state.loadCommentsForRestaurant('online-r1');
        expect(state.commentsForRestaurant('online-r1'), hasLength(2));
        expect(state.hasMoreComments('online-r1'), isTrue);

        await state.loadMoreComments('online-r1');
        expect(state.commentsForRestaurant('online-r1'), hasLength(3));
        expect(state.hasMoreComments('online-r1'), isFalse);

        // The second call must carry the cursor the first page returned.
        expect(repo.cursorsReceived, [null, 'cursor-after-page-1']);
      },
    );

    test(
      'loadMoreComments does nothing when there is no next page',
      () async {
        await seedComment(
          'c1',
          text: 'Only one',
          createdAt: DateTime(2026),
        );
        final countingRepo = CountingCommentRepository(fakeFirestore);
        final state = buildState(commentRepo: countingRepo);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await state.loadCommentsForRestaurant('online-r1');
        expect(state.hasMoreComments('online-r1'), isFalse);
        final callsBefore = countingRepo.getPageCallCount;

        await state.loadMoreComments('online-r1');
        expect(countingRepo.getPageCallCount, callsBefore);
      },
    );

    test(
      'loadCommentsForRestaurant loads replies for each top-level comment',
      () async {
        await seedComment(
          'c1',
          text: 'Parent',
          createdAt: DateTime(2026),
        );
        await seedComment(
          'r1',
          text: 'A reply',
          createdAt: DateTime(2026, 1, 2),
          parentId: 'c1',
        );

        final state = buildState();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await state.loadCommentsForRestaurant('online-r1');

        final replies = state.repliesForComment(
          'c1',
          restaurantId: 'online-r1',
        );
        expect(replies, hasLength(1));
        expect(replies.first.text, 'A reply');
      },
    );

    test(
      'addComment inserts the new comment at index 0, not the end',
      () async {
        await seedComment(
          'c1',
          text: 'Old comment',
          createdAt: DateTime(2026),
        );
        final state = buildState(
          commentRepo: FakeSubmitCommentRepository(firestore: fakeFirestore),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await state.loadCommentsForRestaurant('online-r1');

        await state.addComment(
          restaurantId: 'online-r1',
          text: 'New comment',
        );

        final comments = state.commentsForRestaurant('online-r1');
        expect(comments.first.text, 'New comment');
        expect(comments.last.text, 'Old comment');
      },
    );

    test(
      'addComment bumps restaurant.commentCount locally',
      () async {
        final state = buildState(commentRepo: FakeSubmitCommentRepository());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await state.loadCommentsForRestaurant('online-r1');

        final before = state.restaurantById('online-r1')!.commentCount;
        await state.addComment(
          restaurantId: 'online-r1',
          text: 'New comment',
        );

        expect(
          state.restaurantById('online-r1')!.commentCount,
          before + 1,
        );
      },
    );

    test(
      'addComment appends only the comment returned by the callable',
      () async {
        final state = buildState(commentRepo: FakeSubmitCommentRepository());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await state.loadCommentsForRestaurant('online-r1');

        await state.addComment(
          restaurantId: 'online-r1',
          text: 'New comment',
        );

        final comment = state.commentsForRestaurant('online-r1').first;
        expect(comment.id, 'server-generated-id');
        expect(comment.userName, 'Alice');
      },
    );
  });
}
