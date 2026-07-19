import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      // After successful retry, prices should render.
      expect(callCount, 2);
      expect(find.textContaining(r'$4.99'), findsOneWidget);
      expect(find.textContaining(r'$9.99'), findsOneWidget);
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
      expect(find.textContaining(r'$4.99'), findsOneWidget);
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

      // Prices render in the tier cards.
      expect(find.textContaining(r'$4.99'), findsOneWidget);
      expect(find.textContaining(r'$9.99'), findsOneWidget);

      // No error or loading indicators.
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('Could not load prices'), findsNothing);
    });
  });
}
