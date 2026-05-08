import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';
import 'package:vouch/services/auth_service.dart';

Widget buildTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState()),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider(create: (_) => SavedProvider()),
      ChangeNotifierProvider(create: (_) => SuggestionProvider()),
      ChangeNotifierProvider(create: (_) => AuthService.mock()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedRestaurantsScreen', () {
    testWidgets('shows empty state with no saves', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SavedRestaurantsScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.text('No saved restaurants yet'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Save your favorites and they will appear here',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Saved title', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SavedRestaurantsScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets(
      'shows saved restaurants when populated',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'saved_restaurant_ids': ['hou-1'],
        });

        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows empty bookmark icon',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.byIcon(Icons.bookmark_border),
          findsOneWidget,
        );
      },
    );
  });
}
