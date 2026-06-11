import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/report.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';

/// In-memory fake that records calls without touching Firestore.
class FakeUserRepository implements UserRepository {
  final List<String> blockedIds = [];
  final List<(String, String)> addBlockCalls = [];

  @override
  Future<List<String>> getBlockedIds(String uid) async => List.of(blockedIds);

  @override
  Future<void> addBlock(String blockerUid, String blockedUid) async {
    addBlockCalls.add((blockerUid, blockedUid));
    blockedIds.add(blockedUid);
  }

  @override
  Future<void> removeBlock(String blockerUid, String blockedUid) async {
    blockedIds.remove(blockedUid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// In-memory fake that records submitted reports.
class FakeReportProvider extends ReportProvider {
  FakeReportProvider({required super.authService});

  final List<String> submittedReasons = [];

  @override
  Future<void> submitReport({
    required String commentId,
    required String commentPath,
    required String restaurantId,
    required String cityId,
    required ReportReason reason,
  }) async {
    submittedReasons.add(reason.name);
  }
}

Widget _buildTestApp(
  Widget child, {
  required AuthService auth,
  required FakeUserRepository userRepo,
  required FakeReportProvider reportProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(
        create: (_) => SavedProvider(authService: auth),
      ),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: auth),
      ),
      ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
      Provider<UserRepository>.value(value: userRepo),
      Provider.value(value: AnalyticsService.test([])),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Comment moderation flow', () {
    testWidgets('report: tap menu, pick reason, shows toast', (tester) async {
      // Sign in so the screen shows comment moderation controls.
      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'me',
          email: 'me@test.com',
          method: AuthMethod.email,
        ),
      );
      final userRepo = FakeUserRepository();
      final reportProvider = FakeReportProvider(authService: auth);

      await tester.pumpWidget(
        _buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
          auth: auth,
          userRepo: userRepo,
          reportProvider: reportProvider,
        ),
      );

      // Wait for seed data to load.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      // Scroll down to the comments section.
      await tester.scrollUntilVisible(
        find.text('Comments'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Seed comments belong to user1/user2, not 'me', so the
      // three-dot menu should appear on at least one comment.
      // Scroll further to ensure the menu icon is visible.
      await tester.scrollUntilVisible(
        find.byIcon(Icons.more_vert).first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final menuButton = find.byIcon(Icons.more_vert);
      expect(menuButton, findsWidgets);

      // Tap the first menu button.
      await tester.tap(menuButton.first);
      await tester.pumpAndSettle();

      // The popup should show "Report comment".
      expect(find.text('Report comment'), findsOneWidget);
      expect(find.text('Block this user'), findsOneWidget);

      // Tap "Report comment" to open the report sheet.
      await tester.tap(find.text('Report comment'));
      await tester.pumpAndSettle();

      // The report sheet should show reason options.
      expect(find.text('Why are you reporting this comment?'), findsOneWidget);
      expect(find.text('Spam or advertising'), findsOneWidget);

      // Pick a reason.
      await tester.tap(find.text('Spam or advertising'));
      await tester.pumpAndSettle();

      // The fake provider should have recorded the report.
      expect(reportProvider.submittedReasons, contains('spam'));

      // Success toast should appear.
      expect(find.text('Report submitted. Thank you.'), findsOneWidget);
    });

    testWidgets('block: tap menu, block user, comments disappear',
        (tester) async {
      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'me',
          email: 'me@test.com',
          method: AuthMethod.email,
        ),
      );
      final userRepo = FakeUserRepository();
      final reportProvider = FakeReportProvider(authService: auth);

      await tester.pumpWidget(
        _buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
          auth: auth,
          userRepo: userRepo,
          reportProvider: reportProvider,
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      // Scroll down to the comments section.
      await tester.scrollUntilVisible(
        find.text('Comments'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Scroll to make the menu icon visible and tappable.
      await tester.scrollUntilVisible(
        find.byIcon(Icons.more_vert).first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Verify seed comments are visible (user1 = FoodieH, user2 = HTXLocal).
      // At least one should be visible after scrolling.
      expect(find.byIcon(Icons.more_vert), findsWidgets);

      // Tap the first menu and block the user.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block this user'));
      await tester.pumpAndSettle();

      // The fake repo should have recorded the block call.
      expect(userRepo.addBlockCalls, hasLength(1));

      // The blocked user's comment should be gone.
      // The first seed comment is by user1 (FoodieH), so after blocking
      // user1 only HTXLocal should remain.
      final blockedUserId = userRepo.addBlockCalls.first.$2;
      if (blockedUserId == 'user1') {
        expect(find.text('FoodieH'), findsNothing);
        expect(find.text('HTXLocal'), findsOneWidget);
      } else {
        expect(find.text('HTXLocal'), findsNothing);
        expect(find.text('FoodieH'), findsOneWidget);
      }

      // Toast confirms the block.
      expect(find.text('User blocked.'), findsOneWidget);
    });
  });
}
