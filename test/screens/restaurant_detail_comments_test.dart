import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/city_repository.dart';
import 'package:vouch/repositories/comment_repository.dart';
import 'package:vouch/repositories/restaurant_repository.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';

const _signedInUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

const _restaurant = Restaurant(
  id: 'widget-r1',
  cityId: 'test-city',
  name: 'Widget Test Restaurant',
  cuisine: 'Test',
  imageUrl: '',
  description: 'A test restaurant.',
  rank: 1,
  commentCount: 47,
);

class _StubCityRepository extends CityRepository {
  _StubCityRepository() : super(firestore: FakeFirebaseFirestore());

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

class _StubRestaurantRepository extends RestaurantRepository {
  _StubRestaurantRepository(this.restaurant)
      : super(firestore: FakeFirebaseFirestore());

  final Restaurant restaurant;

  @override
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async =>
      [restaurant];
}

/// getPage never resolves until the test completes [pageCompleter],
/// so the loading state can be observed deterministically instead of
/// racing a real async fetch.
class _DelayedCommentRepository extends CommentRepository {
  _DelayedCommentRepository(this.pageCompleter)
      : super(firestore: FakeFirebaseFirestore());

  final Completer<({List<Comment> comments, String? nextCursor})>
      pageCompleter;

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) =>
      pageCompleter.future;

  @override
  Future<List<Comment>> getReplies(
    String restaurantId,
    String commentId,
  ) async =>
      const [];
}

class _ThrowingCommentRepository extends CommentRepository {
  _ThrowingCommentRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) =>
      throw Exception('Simulated network failure');
}

/// Returns pre-programmed pages in sequence. See the identical fake in
/// app_state_test.dart for why: FakeFirebaseFirestore's
/// startAfterDocument does not return a real second page for this
/// query shape, so pagination orchestration is tested against known
/// canned pages instead of a real cursor round-trip.
class _SequencedCommentRepository extends CommentRepository {
  _SequencedCommentRepository(this._pages)
      : super(firestore: FakeFirebaseFirestore());

  final List<({List<Comment> comments, String? nextCursor})> _pages;
  int _calls = 0;

  @override
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) async {
    final page = _pages[_calls];
    _calls++;
    return page;
  }

  @override
  Future<List<Comment>> getReplies(
    String restaurantId,
    String commentId,
  ) async =>
      const [];
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<List<String>> getBlockedIds(String uid) async => const [];

  @override
  Future<void> addBlock(String blockerUid, String blockedUid) async {}

  @override
  Future<void> removeBlock(String blockerUid, String blockedUid) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Comment _fakeComment(
  String id,
  String text, {
  DateTime? createdAt,
  String? parentId,
}) {
  return Comment(
    id: id,
    restaurantId: _restaurant.id,
    userId: 'user-$id',
    userName: 'User $id',
    text: text,
    createdAt: createdAt ?? DateTime(2026),
    parentId: parentId,
  );
}

Future<void> _seedComment(
  FakeFirebaseFirestore fakeFirestore,
  String id, {
  required String text,
  required DateTime createdAt,
  String? parentId,
}) async {
  await fakeFirestore
      .collection('restaurants')
      .doc(_restaurant.id)
      .collection('comments')
      .doc(id)
      .set({
    'userId': 'user-$id',
    'userName': 'User $id',
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
    'parentId': parentId,
    'isInsider': false,
  });
}

Widget _buildApp({
  required CommentRepository commentRepo,
  AuthService? auth,
}) {
  final authService = auth ?? AuthService.mock(initialUser: _signedInUser);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AppState(
          useFirebase: true,
          cityRepo: _StubCityRepository(),
          restaurantRepo: _StubRestaurantRepository(_restaurant),
          commentRepo: commentRepo,
        ),
      ),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider.value(value: authService),
      ChangeNotifierProvider(
        create: (_) => SavedProvider(authService: authService),
      ),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: authService),
      ),
      ChangeNotifierProvider(
        create: (_) => ReportProvider(authService: authService),
      ),
      Provider<UserRepository>.value(value: _FakeUserRepository()),
      Provider.value(value: AnalyticsService.test([])),
    ],
    child: MaterialApp(
      home: RestaurantDetailScreen(restaurantId: _restaurant.id),
    ),
  );
}

Future<void> _scrollToComments(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
  await tester.pumpAndSettle();
}

/// Pumps a fixed number of frames instead of pumpAndSettle. Needed for
/// tests that hold a fetch open on a never-completing Completer:
/// pumpAndSettle (including the one inside _scrollToComments) waits
/// for the widget tree to go quiet, which never happens while a
/// fetch is deliberately left pending.
Future<void> _pumpFrames(WidgetTester tester, [int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump();
  }
}

Future<void> _scrollToCommentsWithoutSettling(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
  await _pumpFrames(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RestaurantDetailScreen comment loading', () {
    testWidgets(
      'loading state shows before the first page resolves',
      (tester) async {
        final completer =
            Completer<({List<Comment> comments, String? nextCursor})>();
        await tester.pumpWidget(
          _buildApp(commentRepo: _DelayedCommentRepository(completer)),
        );
        await _pumpFrames(tester);
        await _scrollToCommentsWithoutSettling(tester);

        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text('Be the first to weigh in.'), findsNothing);

        completer.complete(
          (comments: [_fakeComment('c1', 'Hello')], nextCursor: null),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello'), findsOneWidget);
      },
    );

    testWidgets(
      'first page loads and renders, header uses restaurant.commentCount',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await _seedComment(
          fakeFirestore,
          'c1',
          text: 'Great food',
          createdAt: DateTime(2026),
        );

        await tester.pumpWidget(
          _buildApp(commentRepo: CommentRepository(firestore: fakeFirestore)),
        );
        await tester.pumpAndSettle();
        await _scrollToComments(tester);

        expect(find.text('Great food'), findsOneWidget);
        // The header and the comment-count pill both show the server
        // aggregate (47), not the size of the loaded page (1).
        expect(find.text('47'), findsWidgets);
      },
    );

    testWidgets(
      'error state shows on failure',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(commentRepo: _ThrowingCommentRepository()),
        );
        await tester.pumpAndSettle();
        await _scrollToComments(tester);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(
          find.textContaining('Simulated network failure'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'empty state is distinguishable from not-yet-loaded',
      (tester) async {
        final completer =
            Completer<({List<Comment> comments, String? nextCursor})>();
        await tester.pumpWidget(
          _buildApp(commentRepo: _DelayedCommentRepository(completer)),
        );
        await _pumpFrames(tester);
        await _scrollToCommentsWithoutSettling(tester);

        // Still loading: the empty-state text must not appear yet,
        // even though there happen to be zero comments loaded so far.
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text('Be the first to weigh in.'), findsNothing);

        completer.complete((comments: <Comment>[], nextCursor: null));
        await tester.pumpAndSettle();

        // Now genuinely loaded and empty: the empty state is correct.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Be the first to weigh in.'), findsOneWidget);
      },
    );

    testWidgets(
      'load-more appears when nextCursor is non-null and disappears '
      'once exhausted',
      (tester) async {
        final repo = _SequencedCommentRepository([
          (
            comments: [_fakeComment('p1', 'Page one comment')],
            nextCursor: 'cursor-a',
          ),
          (
            comments: [_fakeComment('p2', 'Page two comment')],
            nextCursor: null,
          ),
        ]);

        await tester.pumpWidget(_buildApp(commentRepo: repo));
        await tester.pumpAndSettle();
        await _scrollToComments(tester);

        expect(find.text('Load more comments'), findsOneWidget);

        await tester.tap(find.text('Load more comments'));
        await tester.pumpAndSettle();

        expect(find.text('Page one comment'), findsOneWidget);
        expect(find.text('Page two comment'), findsOneWidget);
        expect(find.text('Load more comments'), findsNothing);
      },
    );

    testWidgets(
      'replies render under their parent',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await _seedComment(
          fakeFirestore,
          'c1',
          text: 'Parent comment',
          createdAt: DateTime(2026),
        );
        await _seedComment(
          fakeFirestore,
          'r1',
          text: 'A reply here',
          createdAt: DateTime(2026, 1, 2),
          parentId: 'c1',
        );

        await tester.pumpWidget(
          _buildApp(commentRepo: CommentRepository(firestore: fakeFirestore)),
        );
        await tester.pumpAndSettle();
        await _scrollToComments(tester);

        expect(find.text('Parent comment'), findsOneWidget);
        expect(find.text('A reply here'), findsOneWidget);

        // The reply renders below its parent, not as a sibling top-level
        // comment: its top position is further down the screen.
        final parentY = tester.getTopLeft(find.text('Parent comment')).dy;
        final replyY = tester.getTopLeft(find.text('A reply here')).dy;
        expect(replyY, greaterThan(parentY));
      },
    );

    testWidgets(
      'a newly posted comment appears at the top',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await _seedComment(
          fakeFirestore,
          'c1',
          text: 'Existing comment',
          createdAt: DateTime(2026),
        );

        await tester.pumpWidget(
          _buildApp(commentRepo: CommentRepository(firestore: fakeFirestore)),
        );
        await tester.pumpAndSettle();
        await _scrollToComments(tester);

        await tester.enterText(find.byType(TextField), 'Brand new comment');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(find.text('Brand new comment'), findsOneWidget);
        expect(find.text('Existing comment'), findsOneWidget);

        final newY = tester.getTopLeft(find.text('Brand new comment')).dy;
        final existingY = tester.getTopLeft(find.text('Existing comment')).dy;
        expect(newY, lessThan(existingY));
      },
    );
  });
}
