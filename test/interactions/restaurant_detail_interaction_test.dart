import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/widgets/insider_notes.dart';
import 'package:vouch/widgets/paywall_gate.dart';

import '../helpers/test_app.dart';

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
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Find vote icon
        final voteFinder = find.byIcon(
          Icons.arrow_upward_rounded,
        );
        expect(voteFinder, findsOneWidget);

        // Tap vote
        await tester.tap(voteFinder);
        await tester.pumpAndSettle();

        // Vote count should change (2847 -> 2848,
        // displayed as 2.8k)
        expect(find.text('2.8k'), findsOneWidget);

        // Tap again to un-vote
        await tester.tap(voteFinder);
        await tester.pumpAndSettle();

        // Count back to original
        expect(find.text('2.8k'), findsOneWidget);
      },
    );

    testWidgets(
      'save button locked for free user triggers '
      'upgrade sheet',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const RestaurantDetailScreen(
              restaurantId: 'hou-1',
            ),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Free user sees bookmark_border (locked)
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
        final membership = MembershipProvider(
          initialTier: MembershipTier.localsPass,
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

        // Entitled user sees unsaved bookmark
        final bookmark = find.byIcon(
          Icons.bookmark_border,
        );
        expect(bookmark, findsOneWidget);

        // Tap to save
        await tester.tap(bookmark);
        await tester.pumpAndSettle();

        // Now should show filled bookmark
        expect(
          find.byIcon(Icons.bookmark),
          findsOneWidget,
        );

        // Tap again to unsave
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
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Scroll down to comment section
        await scrollDown(tester, by: 600);

        // Enter comment text
        await tester.enterText(
          find.byType(TextField),
          'Great place!',
        );
        await tester.pump();

        // Tap send
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Comment should appear in list
        expect(
          find.text('Great place!'),
          findsOneWidget,
        );

        // Text field should be cleared
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
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Scroll down to comments
        await scrollDown(tester, by: 600);

        // Tap Reply on first comment
        await tester.tap(find.text('Reply').first);
        await tester.pumpAndSettle();

        // Reply indicator should appear
        expect(
          find.textContaining('Replying to'),
          findsOneWidget,
        );

        // Hint text should change
        expect(
          find.text('Write a reply...'),
          findsOneWidget,
        );

        // Tap cancel (X icon in reply bar)
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Indicator should be gone
        expect(
          find.textContaining('Replying to'),
          findsNothing,
        );

        // Hint text back to default
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

        // Scroll down to paywall area
        await scrollDown(tester, by: 400);

        // Paywall gate should exist
        expect(
          find.byType(PaywallGate),
          findsOneWidget,
        );

        // Real insider tip text must NOT be in tree
        expect(
          find.text(
            'Go on a weekday to skip the '
            '2-hour weekend wait.',
          ),
          findsNothing,
        );

        // Placeholder text IS in tree
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

        // Scroll down to insider notes
        await scrollDown(tester, by: 400);

        // No paywall gate
        expect(
          find.byType(PaywallGate),
          findsNothing,
        );

        // InsiderNotes widget IS present
        expect(
          find.byType(InsiderNotes),
          findsOneWidget,
        );

        // Real content text visible
        expect(
          find.text('Insider Notes'),
          findsOneWidget,
        );
      },
    );
  });
}
