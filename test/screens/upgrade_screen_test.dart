import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/services/revenue_cat_service.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    RevenueCatService.resetSimulatedState();
  });

  group('UpgradeScreen price loading', () {
    testWidgets('shows progress indicators while prices load',
        (tester) async {
      final completer = Completer<Map<String, String>>();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(body: UpgradeScreen(priceLoader: () => completer.future)),
        ),
      );
      await tester.pump();

      // While the completer is pending, progress indicators should show.
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Purchase buttons should be disabled (loading = true).
      final buttons = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .toList();
      for (final b in buttons) {
        expect(b.onPressed, isNull, reason: 'buttons disabled while loading');
      }

      // Clean up: complete the future so the test does not leak.
      completer.complete({
        RevenueCatConfig.localsPassMonthly: r'$4.99',
        RevenueCatConfig.localsPassYearly: r'$29.99',
        RevenueCatConfig.cityInsiderMonthly: r'$9.99',
        RevenueCatConfig.cityInsiderYearly: r'$79.99',
      });
      await tester.pumpAndSettle();
    });

    testWidgets('shows error and Retry on failure, retries on tap',
        (tester) async {
      var callCount = 0;

      // First call: return empty (simulates failure).
      // Second call: return real prices (simulates success after retry).
      Future<Map<String, String>> loader() async {
        callCount++;
        if (callCount == 1) return {};
        return {
          RevenueCatConfig.localsPassMonthly: r'$4.99',
          RevenueCatConfig.localsPassYearly: r'$29.99',
          RevenueCatConfig.cityInsiderMonthly: r'$9.99',
          RevenueCatConfig.cityInsiderYearly: r'$79.99',
        };
      }

      await tester.pumpWidget(
        buildTestApp(Scaffold(body: UpgradeScreen(priceLoader: loader))),
      );
      await tester.pumpAndSettle();

      // Error state: message and Retry button visible.
      expect(find.textContaining('Could not load prices'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tier cards should NOT be visible in the error state.
      expect(find.text('Locals Pass'), findsNothing);

      // Tap Retry.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // After successful retry, prices should render (once in the
      // headline, once in the trial-to-price disclosure line).
      expect(callCount, 2);
      expect(find.textContaining(r'$4.99'), findsNWidgets(2));
      expect(find.textContaining(r'$9.99'), findsNWidgets(2));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('shows error and Retry when loader throws', (tester) async {
      var callCount = 0;

      Future<Map<String, String>> loader() async {
        callCount++;
        if (callCount == 1) throw Exception('network error');
        return {
          RevenueCatConfig.localsPassMonthly: r'$4.99',
          RevenueCatConfig.localsPassYearly: r'$29.99',
          RevenueCatConfig.cityInsiderMonthly: r'$9.99',
          RevenueCatConfig.cityInsiderYearly: r'$79.99',
        };
      }

      await tester.pumpWidget(
        buildTestApp(Scaffold(body: UpgradeScreen(priceLoader: loader))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load prices'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.textContaining(r'$4.99'), findsNWidgets(2));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders prices on success', (tester) async {
      Future<Map<String, String>> loader() async => {
            RevenueCatConfig.localsPassMonthly: r'$4.99',
            RevenueCatConfig.localsPassYearly: r'$29.99',
            RevenueCatConfig.cityInsiderMonthly: r'$9.99',
            RevenueCatConfig.cityInsiderYearly: r'$79.99',
          };

      await tester.pumpWidget(
        buildTestApp(Scaffold(body: UpgradeScreen(priceLoader: loader))),
      );
      await tester.pumpAndSettle();

      // Prices render in the tier cards (headline + trial disclosure).
      expect(find.textContaining(r'$4.99'), findsNWidgets(2));
      expect(find.textContaining(r'$9.99'), findsNWidgets(2));

      // No error or loading indicators.
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('Could not load prices'), findsNothing);
    });

    testWidgets(
      'disables purchase button for a tier missing from a partial price map',
      (tester) async {
        // A non-empty map does not trigger _priceError, but if the
        // current RevenueCat offering is missing a product (e.g. one
        // tier not yet approved in App Store Connect), that tier's
        // price stays null even though _loading is false.
        Future<Map<String, String>> loader() async => {
              RevenueCatConfig.localsPassMonthly: r'$4.99',
              RevenueCatConfig.localsPassYearly: r'$29.99',
            };

        await tester.pumpWidget(
          buildTestApp(Scaffold(body: UpgradeScreen(priceLoader: loader))),
        );
        await tester.pumpAndSettle();

        // No error state; tier cards render normally.
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Locals Pass'), findsOneWidget);
        expect(find.text('City Insider'), findsOneWidget);

        final buttons = tester
            .widgetList<ElevatedButton>(find.byType(ElevatedButton))
            .toList();
        expect(buttons.length, 2);

        // Locals Pass has a price: button enabled.
        expect(buttons[0].onPressed, isNotNull);
        // City Insider is missing from the map (price == null):
        // button must be disabled.
        expect(buttons[1].onPressed, isNull);

        // The trial-to-price line only makes a claim when there is a
        // price to back it up.
        expect(
          find.textContaining('Free for 7 days. After that, you pay '),
          findsOneWidget,
        );
      },
    );
  });

  group('UpgradeScreen legal links', () {
    testWidgets('Terms of Use and Privacy Policy links are tappable',
        (tester) async {
      final launchedUrls = <Uri>[];

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: UpgradeScreen(
              priceLoader: () async => {
                RevenueCatConfig.localsPassMonthly: r'$4.99',
                RevenueCatConfig.localsPassYearly: r'$29.99',
                RevenueCatConfig.cityInsiderMonthly: r'$9.99',
                RevenueCatConfig.cityInsiderYearly: r'$79.99',
              },
              urlLauncher: (uri) async {
                launchedUrls.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Links sit below the fold in the scrollable sheet.
      await tester.ensureVisible(find.text('Terms of Use'));
      await tester.tap(find.text('Terms of Use'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(launchedUrls, [
        Uri.parse(BrandConfig.eulaUrl),
        Uri.parse(BrandConfig.privacyPolicyUrl),
      ]);
    });
  });

  group('UpgradeScreen subscription disclosures', () {
    testWidgets('shows the auto-renewal statement', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: UpgradeScreen(
              priceLoader: () async => {
                RevenueCatConfig.localsPassMonthly: r'$4.99',
                RevenueCatConfig.localsPassYearly: r'$29.99',
                RevenueCatConfig.cityInsiderMonthly: r'$9.99',
                RevenueCatConfig.cityInsiderYearly: r'$79.99',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('renews automatically until you cancel'),
        findsOneWidget,
      );
      expect(find.textContaining('App Store settings'), findsOneWidget);
    });

    testWidgets('post-trial price renders only after prices load',
        (tester) async {
      final completer = Completer<Map<String, String>>();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(body: UpgradeScreen(priceLoader: () => completer.future)),
        ),
      );
      await tester.pump();

      // While loading, the trial-to-price disclosure has not rendered yet.
      expect(
        find.textContaining('Free for 7 days. After that'),
        findsNothing,
      );

      completer.complete({
        RevenueCatConfig.localsPassMonthly: r'$4.99',
        RevenueCatConfig.localsPassYearly: r'$29.99',
        RevenueCatConfig.cityInsiderMonthly: r'$9.99',
        RevenueCatConfig.cityInsiderYearly: r'$79.99',
      });
      await tester.pumpAndSettle();

      expect(
        find.text(
          r'Free for 7 days. After that, you pay $4.99 for 1 month.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          r'Free for 7 days. After that, you pay $9.99 for 1 month.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('duration is stated explicitly, not just a /month suffix',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: UpgradeScreen(
              priceLoader: () async => {
                RevenueCatConfig.localsPassMonthly: r'$4.99',
                RevenueCatConfig.localsPassYearly: r'$29.99',
                RevenueCatConfig.cityInsiderMonthly: r'$9.99',
                RevenueCatConfig.cityInsiderYearly: r'$79.99',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('for 1 month'), findsWidgets);
      expect(find.textContaining('/month'), findsNothing);
    });
  });
}
