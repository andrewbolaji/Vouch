import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/models/suggestion.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/suggestion_repository.dart';
import 'package:vouch/screens/notification_settings_screen.dart';
import 'package:vouch/screens/profile_screen.dart';
import 'package:vouch/screens/saved_restaurants_screen.dart';
import 'package:vouch/screens/sign_in_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/services/auth_service.dart';

import '../helpers/test_app.dart';

const _testUser = AuthUser(
  uid: 'test-uid',
  email: 'test@test.com',
  method: AuthMethod.email,
);

class _FakeSuggestionRepo implements SuggestionRepository {
  @override
  Future<void> submit({
    required String type,
    required String text,
    String? cityId,
  }) async {}
  @override
  Future<int> getRemainingToday(String userId) async => kDailySuggestionCap;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileScreen interactions', () {
    testWidgets(
      'Sign In navigates to SignInScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(SignInScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Saved Restaurants navigates to '
      'SavedRestaurantsScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(
          find.text('Saved Restaurants'),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(SavedRestaurantsScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Upgrade Plan opens UpgradeScreen bottom sheet',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Upgrade Plan'));
        await tester.pumpAndSettle();

        expect(
          find.byType(UpgradeScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Notifications navigates to '
      'NotificationSettingsScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle(seedLoadDuration);

        expect(
          find.byType(NotificationSettingsScreen),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'About opens dialog with app info',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();

        // Dialog shows version and support email
        expect(
          find.text('Version 1.0.0'),
          findsOneWidget,
        );
        expect(
          find.text(BrandConfig.supportEmail),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'suggestion box submits and clears for signed-in user',
      (tester) async {
        final auth = AuthService.mock(initialUser: _testUser);
        final suggestion = SuggestionProvider(
          authService: auth,
          suggestionRepository: _FakeSuggestionRepo(),
        );
        await tester.pumpWidget(
          buildTestApp(
            const ProfileScreen(),
            authOverride: auth,
            suggestionOverride: suggestion,
          ),
        );
        await tester.pumpAndSettle(seedLoadDuration);

        // Drag up to reveal suggestion box
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Suggestion Box'),
          findsOneWidget,
        );

        // Enter suggestion text
        final suggestionField = find.byType(TextField);
        await tester.enterText(
          suggestionField.last,
          'Add more cities please',
        );
        await tester.pump();

        // Tap Submit
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Should show success snackbar
        expect(
          find.text('Suggestion submitted. Thanks!'),
          findsOneWidget,
        );
      },
    );
  });
}
