import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vouch/screens/verify_email_screen.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

Widget _buildTestApp(AuthService auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      Provider.value(value: AnalyticsService.test([])),
    ],
    child: MaterialApp(
      theme: AppTheme.themeData,
      home: const VerifyEmailScreen(),
    ),
  );
}

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('shows email address and instructions', (tester) async {
      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'u1',
          email: 'test@example.com',
          method: AuthMethod.email,
        ),
      );
      await tester.pumpWidget(_buildTestApp(auth));

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(
        find.textContaining('test@example.com'),
        findsOneWidget,
      );
      expect(
        find.textContaining('spam or promotions folder'),
        findsOneWidget,
      );
    });

    testWidgets('shows Continue and Resend buttons', (tester) async {
      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'u1',
          email: 'test@example.com',
          method: AuthMethod.email,
        ),
      );
      await tester.pumpWidget(_buildTestApp(auth));

      expect(find.text('Continue'), findsOneWidget);
      expect(
        find.text('Resend verification email'),
        findsOneWidget,
      );
    });

    testWidgets('shows sign-out option', (tester) async {
      final auth = AuthService.mock(
        initialUser: const AuthUser(
          uid: 'u1',
          email: 'test@example.com',
          method: AuthMethod.email,
        ),
      );
      await tester.pumpWidget(_buildTestApp(auth));

      expect(
        find.text('Use a different account'),
        findsOneWidget,
      );
    });

    testWidgets('needsEmailVerification is correct', (tester) async {
      const unverified = AuthUser(
        uid: 'u1',
        email: 'a@b.com',
        method: AuthMethod.email,
      );
      expect(unverified.needsEmailVerification, isTrue);

      const verified = AuthUser(
        uid: 'u2',
        email: 'a@b.com',
        method: AuthMethod.email,
        emailVerified: true,
      );
      expect(verified.needsEmailVerification, isFalse);

      const googleUser = AuthUser(
        uid: 'u3',
        email: 'a@b.com',
        method: AuthMethod.google,
        emailVerified: true,
      );
      expect(googleUser.needsEmailVerification, isFalse);

      const appleUser = AuthUser(
        uid: 'u4',
        email: 'a@b.com',
        method: AuthMethod.apple,
        emailVerified: true,
      );
      expect(appleUser.needsEmailVerification, isFalse);

      const anonymous = AuthUser(uid: 'u5');
      expect(anonymous.needsEmailVerification, isFalse);
    });
  });
}
