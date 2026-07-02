import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/screens/sign_in_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/widgets/insider_notes.dart';
import 'package:vouch/widgets/paywall_gate.dart';

import '../helpers/test_app.dart';

const _testUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

/// Scrolls the CustomScrollView down by the given
/// amount to reveal content below the SliverAppBar.
Future<void> scrollDown(
  WidgetTester tester, {
  double by = 500,
}) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.drag(scrollable, Offset(0, -by));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RestaurantDetailScreen interactions', () {
    testWidgets(
      'vote button toggles state and updates count',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            authOverride: AuthService.mock(initialUser: _testUser),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        final voteFinder = find.byIcon(
          Icons.arrow_upward_rounded,
        );
        expect(voteFinder, findsOneWidget);

        await tester.tap(voteFinder);
        await tester.pumpAndSettle();

        expect(find.text('2.8k'), findsOneWidget);

        await tester.tap(voteFinder);
        await tester.pumpAndSettle();

        expect(find.text('2.8k'), findsOneWidget);
      },
    );

    testWidgets(
      'save button for signed-out user navigates to sign-in',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        final lockBookmark = find.byIcon(
          Icons.bookmark_border,
        );
        expect(lockBookmark, findsOneWidget);

        await tester.tap(lockBookmark);
        await tester.pumpAndSettle();

        expect(
          find.byType(SignInScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'save button locked for signed-in free user '
      'triggers upgrade sheet',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            authOverride: auth,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        final lockBookmark = find.byIcon(
          Icons.bookmark_border,
        );
        expect(lockBookmark, findsOneWidget);

        await tester.tap(lockBookmark);
        await tester.pumpAndSettle();

        expect(
          find.byType(UpgradeScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'save button toggles for entitled user',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        final membership = MembershipProvider(
          initialTier: MembershipTier.localsPass,
        );

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            membershipOverride: membership,
            authOverride: auth,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        final bookmark = find.byIcon(
          Icons.bookmark_border,
        );
        expect(bookmark, findsOneWidget);

        await tester.tap(bookmark);
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.bookmark),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.bookmark));
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.bookmark_border),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'submitting comment clears field and shows '
      'comment in list',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            authOverride: AuthService.mock(initialUser: _testUser),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await scrollDown(tester, by: 600);

        await tester.enterText(
          find.byType(TextField),
          'Great place!',
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(
          find.text('Great place!'),
          findsOneWidget,
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'reply flow shows indicator and clears on '
      'cancel',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            authOverride: AuthService.mock(initialUser: _testUser),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await scrollDown(tester, by: 600);

        await tester.tap(find.text('Reply').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Replying to'),
          findsOneWidget,
        );

        expect(
          find.text('Write a reply...'),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Replying to'),
          findsNothing,
        );

        expect(
          find.text('Add a comment...'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'insider notes withheld from widget tree '
      'when locked (security)',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await scrollDown(tester, by: 400);

        expect(
          find.byType(PaywallGate),
          findsOneWidget,
        );

        // "Tantanmen" appears only in Mensho's whatToOrder.
        // If this is findsNothing, the secret content is correctly
        // withheld from the widget tree when the user is not entitled.
        expect(
          find.textContaining('Tantanmen'),
          findsNothing,
        );

        expect(
          find.textContaining('Unlock to see'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'insider notes shown when entitled (security)',
      (tester) async {
        final membership = MembershipProvider(
          initialTier: MembershipTier.cityInsider,
        );

        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
            membershipOverride: membership,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await scrollDown(tester, by: 400);

        expect(
          find.byType(PaywallGate),
          findsNothing,
        );

        expect(
          find.byType(InsiderNotes),
          findsOneWidget,
        );

        // The same canary string that was withheld when locked
        // must now be visible when the user is entitled.
        expect(
          find.textContaining('Tantanmen'),
          findsWidgets,
        );
      },
    );
  });
}
