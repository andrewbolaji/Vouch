/// Sealed exception hierarchy for Vouch.
///
/// Presentation layer pattern-matches on these types to show
/// user-facing error messages. Raw Firebase exceptions never
/// reach the UI.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

// -- Network --

class NetworkException extends AppException {
  const NetworkException([
    super.message = "Couldn't reach Vouch. "
        'Check your connection and try again.',
  ]);
}

// -- Auth --

enum AuthErrorKind {
  invalidCredentials,
  userNotFound,
  emailAlreadyInUse,
  weakPassword,
  tooManyRequests,
  requiresRecentLogin,
  accountDeletionFailed,
  unknown,
}

class AuthException extends AppException {
  const AuthException({
    required this.kind,
    required String message,
  }) : super(message);

  final AuthErrorKind kind;

  static const invalidCredentials = AuthException(
    kind: AuthErrorKind.invalidCredentials,
    message: 'Wrong email or password. Please try again.',
  );

  static const userNotFound = AuthException(
    kind: AuthErrorKind.userNotFound,
    message: 'No account found with that email. '
        'Check the spelling or create a new account.',
  );

  static const emailAlreadyInUse = AuthException(
    kind: AuthErrorKind.emailAlreadyInUse,
    message: 'That email is already in use. '
        'Try signing in instead.',
  );

  static const weakPassword = AuthException(
    kind: AuthErrorKind.weakPassword,
    message: 'Password is too short. '
        'Use at least 6 characters.',
  );

  static const tooManyRequests = AuthException(
    kind: AuthErrorKind.tooManyRequests,
    message: 'Too many attempts. '
        'Wait a few minutes and try again.',
  );

  static const requiresRecentLogin = AuthException(
    kind: AuthErrorKind.requiresRecentLogin,
    message: 'For security, please sign in again to confirm deletion.',
  );

  static const accountDeletionFailed = AuthException(
    kind: AuthErrorKind.accountDeletionFailed,
    message: 'Could not delete your account right now. '
        'Please try again later.',
  );

  static const unknown = AuthException(
    kind: AuthErrorKind.unknown,
    message: 'Something went wrong. Please try again.',
  );
}

// -- Firestore --

class PermissionDenied extends AppException {
  const PermissionDenied([
    super.message = "You don't have permission to do that.",
  ]);
}

class NotFound extends AppException {
  const NotFound([
    super.message = "That content doesn't exist or was removed.",
  ]);
}

class ServiceUnavailable extends AppException {
  const ServiceUnavailable([
    super.message = 'Vouch is temporarily unavailable. '
        'Please try again in a moment.',
  ]);
}

class RateLimited extends AppException {
  const RateLimited([
    super.message = "You've hit the limit for today. "
        'Try again tomorrow.',
  ]);
}

class FirestoreWriteException extends AppException {
  const FirestoreWriteException([
    super.message = 'Could not save your changes. '
        'Check your connection and try again.',
  ]);
}
