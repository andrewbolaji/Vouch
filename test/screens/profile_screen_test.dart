import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/profile_screen.dart';
import 'package:vouch/services/auth_service.dart';

Widget buildTestApp(Widget child) {
  final auth = AuthService.mock();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider(create: (_) => SavedProvider(authService: auth)),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: auth),
      ),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileScreen', () {
    testWidgets('shows profile title', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets(
      'shows sign in when not authenticated',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets('shows menu items', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfileScreen()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 700),
      );

      expect(
        find.text('Saved Restaurants'),
        findsOneWidget,
      );
      expect(find.text('Upgrade Plan'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets(
      'shows suggestion box',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.text('Suggestion Box'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows anonymous name when not signed in',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(
          find.text('Local (sign in to save)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows Free tier badge by default',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ProfileScreen()),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 700),
        );

        expect(find.text('Free'), findsOneWidget);
      },
    );
  });
}
