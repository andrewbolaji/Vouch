import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/screens/city_detail_screen.dart';
import 'package:vouch/screens/home_screen.dart';
import 'package:vouch/screens/profile_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeScreen interactions', () {
    testWidgets(
      'search filters city grid and clearing restores it',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const HomeScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // At least first 2 cities visible
        expect(find.text('Houston, TX'), findsOneWidget);
        expect(find.text('New York, NY'), findsOneWidget);

        // Type to filter
        await tester.enterText(
          find.byType(TextField),
          'Houston',
        );
        await tester.pump();

        expect(find.text('Houston, TX'), findsOneWidget);
        expect(find.text('New York, NY'), findsNothing);

        // Clear restores all
        await tester.enterText(
          find.byType(TextField),
          '',
        );
        await tester.pump();

        expect(find.text('Houston, TX'), findsOneWidget);
        expect(find.text('New York, NY'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a city navigates to CityDetailScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const HomeScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Tap Houston city card
        await tester.tap(find.text('Houston, TX'));
        await tester.pumpAndSettle(seedLoadDuration);

        // Should navigate to CityDetailScreen
        expect(
          find.byType(CityDetailScreen),
          findsOneWidget,
        );
        // City name in app bar
        expect(find.text('Houston, TX'), findsOneWidget);
        // Houston's #1 restaurant visible
        expect(
          find.text('Turkey Leg Hut'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping profile button navigates to ProfileScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const HomeScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(
          find.byIcon(Icons.person_outline),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(ProfileScreen),
          findsOneWidget,
        );
        expect(find.text('Profile'), findsOneWidget);
      },
    );
  });
}
