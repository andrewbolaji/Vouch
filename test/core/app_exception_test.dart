import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/core/error/app_exception.dart';

void main() {
  group('AppException hierarchy', () {
    test('NetworkException has user-friendly message', () {
      const e = NetworkException();
      expect(e.message, contains('Check your connection'));
      expect(e.toString(), equals(e.message));
    });

    test('NetworkException accepts custom message', () {
      const e = NetworkException('Custom network error');
      expect(e.message, equals('Custom network error'));
    });

    test('AuthException static constants have correct kinds', () {
      expect(
        AuthException.invalidCredentials.kind,
        AuthErrorKind.invalidCredentials,
      );
      expect(AuthException.userNotFound.kind, AuthErrorKind.userNotFound);
      expect(
        AuthException.emailAlreadyInUse.kind,
        AuthErrorKind.emailAlreadyInUse,
      );
      expect(AuthException.weakPassword.kind, AuthErrorKind.weakPassword);
      expect(
        AuthException.tooManyRequests.kind,
        AuthErrorKind.tooManyRequests,
      );
      expect(
        AuthException.accountDeletionFailed.kind,
        AuthErrorKind.accountDeletionFailed,
      );
      expect(AuthException.unknown.kind, AuthErrorKind.unknown);
    });

    test('all auth messages are 9th-grade readable (no Firebase jargon)', () {
      final messages = [
        AuthException.invalidCredentials.message,
        AuthException.userNotFound.message,
        AuthException.emailAlreadyInUse.message,
        AuthException.weakPassword.message,
        AuthException.tooManyRequests.message,
        AuthException.accountDeletionFailed.message,
        AuthException.unknown.message,
      ];
      for (final msg in messages) {
        expect(msg, isNot(contains('Firebase')));
        expect(msg, isNot(contains('auth/')));
        expect(msg, isNot(contains('Exception')));
      }
    });

    test('sealed class exhaustive switch works', () {
      // Verifies the sealed hierarchy supports pattern matching.
      const AppException e = AuthException.invalidCredentials;
      final result = switch (e) {
        NetworkException() => 'network',
        AuthException() => 'auth:${e.kind}',
        PermissionDenied() => 'denied',
        NotFound() => 'not-found',
        ServiceUnavailable() => 'unavailable',
        RateLimited() => 'limited',
        FirestoreWriteException() => 'write-error',
      };
      expect(result, equals('auth:${AuthErrorKind.invalidCredentials}'));
    });

    test('PermissionDenied has default message', () {
      const e = PermissionDenied();
      expect(e.message, contains('permission'));
    });

    test('RateLimited has default message', () {
      const e = RateLimited();
      expect(e.message, contains('limit'));
    });
  });
}
