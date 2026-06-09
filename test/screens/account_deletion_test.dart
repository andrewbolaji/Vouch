import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/screens/profile_screen.dart';
import 'package:vouch/services/auth_service.dart';

/// Fake AuthService that lets tests control deleteAccount behavior.
class FakeAuthService extends AuthService {
  FakeAuthService() : super.mock(
    initialUser: const AuthUser(
      uid: 'test-uid',
      email: 'test@example.com',
      method: AuthMethod.email,
    ),
  );

  bool shouldRequireRecentLogin = false;
  bool deleteWasCalled = false;
  bool reauthWasCalled = false;
  int deleteCallCount = 0;

  @override
  Future<String> deleteAccount() async {
    deleteCallCount++;
    deleteWasCalled = true;
    if (shouldRequireRecentLogin && deleteCallCount == 1) {
      throw AuthException.requiresRecentLogin;
    }
    // Simulate clearing the user after deletion.
    setMockUser(null);
    return 'test-uid';
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    reauthWasCalled = true;
    if (password == 'wrong') {
      throw AuthException.invalidCredentials;
    }
  }

  @override
  AuthMethod? get currentAuthMethod => AuthMethod.email;
}

Widget _buildTestApp(Widget child, {required FakeAuthService auth}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(useFirebase: false)),
      ChangeNotifierProvider(create: (_) => MembershipProvider()),
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider(
        create: (_) => SavedProvider(authService: auth),
      ),
      ChangeNotifierProvider(
        create: (_) => SuggestionProvider(authService: auth),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'saved_restaurant_ids_test-uid': <String>['hou-1'],
      'suggestion_remaining_test-uid': 1,
      'voted_restaurant_ids': <String>['hou-1'],
      'notifications_ranking_alerts': true,
    });
  });

  group('Account deletion', () {
    testWidgets('happy path: tap Delete, confirm, shows toast',
        (tester) async {
      final auth = FakeAuthService();

      await tester.pumpWidget(
        _buildTestApp(const ProfileScreen(), auth: auth),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      // Scroll to find the Delete Account button.
      await tester.scrollUntilVisible(
        find.text('Delete Account'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Tap Delete Account.
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(
        find.text('This will permanently delete your account '
            'and all your data. This cannot be undone.'),
        findsOneWidget,
      );

      // Tap the Delete button in the dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // deleteAccount should have been called.
      expect(auth.deleteWasCalled, isTrue);

      // Success toast should appear.
      expect(find.text('Account deleted.'), findsOneWidget);

      // Local data should be cleared.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('saved_restaurant_ids_test-uid'), isNull);
      expect(prefs.getInt('suggestion_remaining_test-uid'), isNull);
      expect(prefs.getStringList('voted_restaurant_ids'), isNull);
      expect(prefs.getBool('notifications_ranking_alerts'), isNull);
    });

    testWidgets('requires-recent-login shows password re-auth dialog',
        (tester) async {
      final auth = FakeAuthService()..shouldRequireRecentLogin = true;

      await tester.pumpWidget(
        _buildTestApp(const ProfileScreen(), auth: auth),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Delete Account'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Tap Delete in confirmation dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Re-auth dialog should appear (email user gets password prompt).
      expect(find.text('Confirm your password'), findsOneWidget);

      // Enter password and confirm.
      // Use the TextField inside the AlertDialog to avoid conflicts.
      final passwordField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(passwordField, 'correct-password');
      await tester.tap(find.text('Confirm and delete'));
      await tester.pumpAndSettle();

      // Both re-auth and delete should have been called.
      expect(auth.reauthWasCalled, isTrue);
      expect(auth.deleteCallCount, 2);

      // Success toast.
      expect(find.text('Account deleted.'), findsOneWidget);
    });

    testWidgets('cancel in confirmation dialog does not delete',
        (tester) async {
      final auth = FakeAuthService();

      await tester.pumpWidget(
        _buildTestApp(const ProfileScreen(), auth: auth),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Delete Account'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.deleteWasCalled, isFalse);
    });
  });
}
