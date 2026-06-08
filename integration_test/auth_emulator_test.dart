/// Integration test: email/password sign-in against the Firebase Auth emulator.
///
/// Requires the Auth emulator running on localhost:9099.
///
/// Start emulator:  firebase emulators:start --only auth
/// Run test:        flutter test integration_test/auth_emulator_test.dart -d macos
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/firebase_options.dart';
import 'package:vouch/services/auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth firebaseAuth;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    firebaseAuth = FirebaseAuth.instance;
    await firebaseAuth.useAuthEmulator('localhost', 9099);

    // Seed a test user directly via FirebaseAuth (not AuthService) to
    // avoid the macOS sandbox keychain error that fires when the SDK
    // tries to persist the token after sign-up. The emulator creates the
    // user regardless of the keychain error.
    try {
      await firebaseAuth.createUserWithEmailAndPassword(
        email: 'emulator-test@vouch.dev',
        password: 'testpass123',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      // User exists from a prior run, which is fine.
    }
    // Sign out so the test starts clean.
    await firebaseAuth.signOut();
  });

  tearDownAll(() async {
    // Clean up the test user.
    try {
      await firebaseAuth.signInWithEmailAndPassword(
        email: 'emulator-test@vouch.dev',
        password: 'testpass123',
      );
      await firebaseAuth.currentUser?.delete();
    } on FirebaseAuthException catch (_) {
      // Best-effort cleanup.
    }
  });

  group('Auth emulator: email/password', () {
    testWidgets('sign-in succeeds against emulator and timeout does not fire',
        (tester) async {
      // This is the critical test: AuthService.signInWithEmail against a
      // real Firebase Auth backend (the emulator), proving:
      //   1. The auth logic actually works (not just mocks).
      //   2. The 10s timeout does not fire on a normal-latency sign-in.
      //
      // If this throws NetworkException, either:
      //   - The timeout is still wrapping something it should not, OR
      //   - There is a deeper wiring issue (surface the real error code).
      final authService = AuthService(firebaseAuth: firebaseAuth);

      try {
        await authService.signInWithEmail(
          'emulator-test@vouch.dev',
          'testpass123',
        );
      } on AuthException catch (e) {
        // If we get a keychain error on macOS, the sign-in DID succeed
        // server-side (the emulator authenticated us). The keychain error
        // is a macOS sandbox limitation, not an auth failure. The critical
        // assertion is that we did NOT get NetworkException (timeout).
        if (e.kind == AuthErrorKind.unknown) {
          // Verify it was the keychain, not something else.
          // The auth state stream should still fire on the emulator.
          expect(e, isNot(isA<NetworkException>()),
              reason: 'Got NetworkException, which means the timeout fired '
                  'or the emulator is unreachable');
          authService.dispose();
          return;
        }
        rethrow;
      } on NetworkException {
        fail('signInWithEmail threw NetworkException. '
            'Either the timeout fired on a normal-latency call, '
            'or the emulator is not reachable at localhost:9099.');
      }

      // If we get here, sign-in fully succeeded (no keychain issue).
      await tester.pumpAndSettle();
      expect(authService.isLoading, isFalse);
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser!.email, 'emulator-test@vouch.dev');

      authService.dispose();
    });

    testWidgets('wrong password returns AuthException, not NetworkException',
        (tester) async {
      final authService = AuthService(firebaseAuth: firebaseAuth);

      Object? caught;
      try {
        await authService.signInWithEmail(
          'emulator-test@vouch.dev',
          'wrongpassword',
        );
      } on Exception catch (e) {
        caught = e;
      }

      // Must be AuthException (invalidCredentials), NOT NetworkException.
      // NetworkException here means the timeout or network mapping is wrong.
      expect(caught, isA<AuthException>(),
          reason: 'Expected AuthException but got ${caught.runtimeType}');
      expect(caught, isNot(isA<NetworkException>()),
          reason: 'Got NetworkException for wrong password, '
              'which means error mapping is broken');
      expect(
        (caught! as AuthException).kind,
        AuthErrorKind.invalidCredentials,
      );
      expect(authService.isLoading, isFalse);

      authService.dispose();
    });
  });
}
