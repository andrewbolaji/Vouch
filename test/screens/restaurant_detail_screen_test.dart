import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';

const _signedInUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

Widget buildTestApp(Widget child, {AuthService? authOverride}) {
  final auth = authOverride ?? AuthService.mock();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider(create: (_) => SavedProvider(authService: auth)),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: auth),
      ),
      ChangeNotifierProvider(
        create: (_) => ReportProvider(authService: auth),
      ),
      ChangeNotifierProvider.value(value: auth),
      Provider.value(value: AnalyticsService.test([])),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RestaurantDetailScreen', () {
    testWidgets('shows not found for bad id', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'invalid',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.text('Restaurant not found'),
        findsOneWidget,
      );
    });

    testWidgets('shows restaurant name', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Mensho'), findsOneWidget);
    });

    testWidgets('has comment input when signed in', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
          authOverride: AuthService.mock(initialUser: _signedInUser),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows vote button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(
            restaurantId: 'hou-1',
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.byIcon(Icons.arrow_upward_rounded),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows share button in app bar',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.byIcon(Icons.share_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows comment action button in action row', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Speech-bubble icon appears in the action row
      expect(
        find.byIcon(Icons.chat_bubble_outline),
        findsWidgets,
      );
    });

    // A1: Empty state renders for a restaurant with zero comments.
    // hou-11 (Tacos Los Brothers) has no seed comments.
    testWidgets('shows empty state when signed in, no comments (hou-11)',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-11'),
          authOverride: AuthService.mock(initialUser: _signedInUser),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Be the first to weigh in.'), findsOneWidget);
      // The empty-state speech bubble icon
      expect(find.byIcon(Icons.chat_bubble_outline), findsWidgets);
    });

    // A2: Header count renders the actual formatted count next to Comments.
    // hou-1 (Mensho) has 2 seed comments.
    testWidgets('comments section header shows actual count', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Find the header Row that contains both 'Comments' and the count.
      // The header is a Row with Text('Comments') + Text('2').
      final headerRow = find.ancestor(
        of: find.text('Comments'),
        matching: find.byType(Row),
      );
      expect(headerRow, findsOneWidget);

      // The count '2' must be inside that same Row, not just anywhere on screen
      final countInHeader = find.descendant(
        of: headerRow,
        matching: find.text('2'),
      );
      expect(countInHeader, findsOneWidget);
    });

    // A3: Comments section renders above the City Insider paywall gate.
    // Uses default (free, non-insider) user so PaywallGate is present.
    testWidgets('comments header renders above paywall gate', (tester) async {
      // hou-1 has insiderTip/whatToOrder, so the paywall gate shows for free users
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Scroll to reveal both sections
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();

      final commentsFinder = find.text('Comments');
      final paywallFinder = find.text('City Insider exclusive');

      expect(commentsFinder, findsOneWidget);
      expect(paywallFinder, findsOneWidget);

      final commentsBox = tester.getTopLeft(commentsFinder);
      final paywallBox = tester.getTopLeft(paywallFinder);

      // Comments header dy should be less (higher on screen) than paywall
      expect(commentsBox.dy, lessThan(paywallBox.dy));
    });

    // Condition 3: signed-out user sees prompt, not input or crash
    testWidgets('signed-out user sees sign-in prompt instead of comment input',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const RestaurantDetailScreen(restaurantId: 'hou-11'),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // No TextField visible (comment input hidden)
      expect(find.byType(TextField), findsNothing);
      // Sign-in prompt visible
      expect(
        find.text('Sign in to join the conversation'),
        findsOneWidget,
      );
      // Empty state text for signed-out
      expect(
        find.text('Sign in to see and post comments.'),
        findsOneWidget,
      );
    });
  });
}
