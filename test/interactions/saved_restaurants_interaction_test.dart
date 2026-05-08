import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedRestaurantsScreen interactions', () {
    testWidgets(
      'empty state shown when nothing is saved',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.text('No saved restaurants yet'),
          findsOneWidget,
        );
        expect(
          find.byIcon(Icons.bookmark_border),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping saved restaurant navigates to detail',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'saved_restaurant_ids': ['hou-1'],
        });

        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Saved restaurant should be visible
        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );

        // Tap it
        await tester.tap(find.text('Turkey Leg Hut'));
        await tester.pumpAndSettle(seedLoadDuration);

        // Should navigate to detail
        expect(
          find.byType(RestaurantDetailScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'multiple saved restaurants grouped by city',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'saved_restaurant_ids': ['hou-1', 'nyc-1'],
        });

        await tester.pumpWidget(
          buildTestApp(const SavedRestaurantsScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Both restaurants visible
        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );
        expect(
          find.text('Peter Luger'),
          findsOneWidget,
        );

        // City headers visible
        expect(
          find.text('Houston, TX'),
          findsOneWidget,
        );
        expect(
          find.text('New York, NY'),
          findsOneWidget,
        );
      },
    );
  });
}
