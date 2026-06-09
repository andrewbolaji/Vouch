import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/city_detail_screen.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/widgets/paywall_gate.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CityDetailScreen interactions', () {
    testWidgets(
      'Top 5 / Top 10 toggle changes visible content',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Top 5 active by default — rank 1 visible
        expect(
          find.text('Mensho'),
          findsOneWidget,
        );

        // Tap Top 10 toggle
        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // Paywall gate should appear for free users
        expect(
          find.byType(PaywallGate),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'paywall gate shows for free user on Top 10',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // Should see paywall message
        expect(
          find.text('Unlock Top 10 with Locals Pass'),
          findsOneWidget,
        );
        // Should NOT see real restaurant names
        // behind the paywall (security: content
        // withheld from tree)
        expect(find.text('Himalaya'), findsNothing);
        expect(find.text('Xochi'), findsNothing);
      },
    );

    testWidgets(
      'entitled user sees Top 6-10 restaurants '
      'without paywall',
      (tester) async {
        final membership = MembershipProvider(
          initialTier: MembershipTier.localsPass,
        );

        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
            membershipOverride: membership,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // No paywall
        expect(
          find.byType(PaywallGate),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping paywall shows upgrade message',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Top 10'));
        await tester.pumpAndSettle();

        // Paywall CTA should be visible
        expect(
          find.text('See plans'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Unlock Top 10 with Locals Pass',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping restaurant navigates to detail screen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const CityDetailScreen(cityId: 'houston'),
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Mensho'));
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(RestaurantDetailScreen),
          findsOneWidget,
        );
      },
    );
  });
}
