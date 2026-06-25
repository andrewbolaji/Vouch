import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/secure_storage_service.dart';

enum AuthMethod { anonymous, email, google, apple }

class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.method = AuthMethod.anonymous,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final AuthMethod method;
  final bool emailVerified;

  bool get isAnonymous => method == AuthMethod.anonymous;

  /// True when this is an email/password user who has not yet
  /// clicked the verification link.
  bool get needsEmailVerification =>
      method == AuthMethod.email && !emailVerified;
}

/// Timeout for non-interactive Firebase Auth calls (email, backend ops).
/// Interactive provider sign-ins (Google, Apple) are NOT timed because the
/// user controls how long the OAuth consent screen takes.
const _authTimeout = Duration(seconds: 10);

class AuthService extends ChangeNotifier {
  /// Production constructor: uses real Firebase Auth.
  AuthService({
    fb.FirebaseAuth? firebaseAuth,
    SecureStorageService? secureStorage,
    AnalyticsService? analyticsService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _secureStorage = secureStorage ?? SecureStorageService(),
        _analyticsService = analyticsService,
        _authSub = (firebaseAuth ?? fb.FirebaseAuth.instance)
            .authStateChanges()
            .listen(null) {
    _authSub?.onData(_onAuthStateChanged);
  }

  /// Test-only constructor: skips Firebase, sets initial state directly.
  AuthService.mock({AuthUser? initialUser})
      : _firebaseAuth = null,
        _secureStorage = null,
        _analyticsService = null,
        _authSub = null {
    _currentUser = initialUser;
  }

  final fb.FirebaseAuth? _firebaseAuth;
  final SecureStorageService? _secureStorage;
  final AnalyticsService? _analyticsService;
  final StreamSubscription<fb.User?>? _authSub;

  AuthUser? _currentUser;
  bool _isLoading = false;

  /// Test only: updates the current user and notifies listeners.
  @visibleForTesting
  void setMockUser(AuthUser? user) {
    assert(
      _firebaseAuth == null,
      'setMockUser is only for .mock() instances',
    );
    _currentUser = user;
    notifyListeners();
  }

  // Display-name caching keys (SharedPreferences, not sensitive)
  static const String _prefKeyUserName = 'auth_user_name';
  static const String _prefKeyUserEmail = 'auth_user_email';

  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null && !_currentUser!.isAnonymous;
  String get displayName =>
      _currentUser?.displayName ??
      _currentUser?.email ??
      'Local (sign in to save)';

  // -- Stream listener --

  void _onAuthStateChanged(fb.User? fbUser) {
    if (fbUser == null) {
      _currentUser = null;
      _setCrashlyticsUserId('');
      _analyticsService?.setSignInMethod('anonymous');
    } else {
      _currentUser = _mapFirebaseUser(fbUser);
      unawaited(_cacheDisplayInfo(fbUser));
      unawaited(_persistToken(fbUser));
      _setCrashlyticsUserId(fbUser.uid);
      _analyticsService?.setSignInMethod(_currentUser!.method.name);
    }
    notifyListeners();
  }

  AuthUser _mapFirebaseUser(fb.User fbUser) {
    AuthMethod method;
    if (fbUser.providerData.any((p) => p.providerId == 'apple.com')) {
      method = AuthMethod.apple;
    } else if (fbUser.providerData.any((p) => p.providerId == 'google.com')) {
      method = AuthMethod.google;
    } else if (fbUser.providerData.any((p) => p.providerId == 'password')) {
      method = AuthMethod.email;
    } else {
      method = AuthMethod.anonymous;
    }

    return AuthUser(
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: fbUser.displayName,
      photoUrl: fbUser.photoURL,
      method: method,
      emailVerified: fbUser.emailVerified,
    );
  }

  Future<void> _cacheDisplayInfo(fb.User fbUser) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fbUser.displayName != null) {
        await prefs.setString(_prefKeyUserName, fbUser.displayName!);
      }
      if (fbUser.email != null) {
        await prefs.setString(_prefKeyUserEmail, fbUser.email!);
      }
    } on Exception catch (e) {
      _log('cache', 'failed to cache display info: $e');
    }
  }

  Future<void> _persistToken(fb.User fbUser) async {
    try {
      final token = await fbUser.getIdToken();
      if (token != null) {
        await _secureStorage?.saveToken(token);
      }
    } on Exception catch (e) {
      _log('token', 'failed to persist token: $e');
    }
  }

  Future<void> _clearPersistedData() async {
    await _secureStorage?.clearAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyUserName);
      await prefs.remove(_prefKeyUserEmail);
    } on Exception catch (e) {
      _log('signout', 'failed to clear cached data: $e');
    }
  }

  // -- Public auth methods --

  /// Sign in with email and password.
  /// Throws [AuthException] or [NetworkException] on failure.
  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      await _firebaseAuth!
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_authTimeout, onTimeout: _onTimeout);
      _analyticsService?.logSignIn(method: 'email');
    } on fb.FirebaseAuthException catch (e) {
      _log('email', 'FirebaseAuthException: '
          'code=${e.code}, message=${e.message}');
      _setLoading(false);
      throw _mapAuthException(e);
    } on TimeoutException {
      _log('email', 'TimeoutException after $_authTimeout');
      _setLoading(false);
      throw const NetworkException();
    } on Exception catch (e) {
      _log('email', 'unexpected: ${e.runtimeType}: $e');
      _setLoading(false);
      throw AuthException.unknown;
    }
    _setLoading(false);
  }

  /// Create a new account with email, password, and display name.
  /// Throws [AuthException] or [NetworkException] on failure.
  Future<void> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    _setLoading(true);
    try {
      final credential = await _firebaseAuth!
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(_authTimeout, onTimeout: _onTimeout);
      await credential.user?.updateDisplayName(name);
      // Force a reload so displayName is available immediately
      await credential.user?.reload();
      if (credential.user != null) {
        await credential.user!.sendEmailVerification();
        _log('signup', 'verification email sent');
      } else {
        _log('signup', 'verification email skipped: user was null');
      }
      _analyticsService?.logSignUp(method: 'email');
    } on fb.FirebaseAuthException catch (e) {
      _log('signup', 'FirebaseAuthException: '
          'code=${e.code}, message=${e.message}');
      _setLoading(false);
      throw _mapAuthException(e);
    } on TimeoutException {
      _log('signup', 'TimeoutException after $_authTimeout');
      _setLoading(false);
      throw const NetworkException();
    } on Exception catch (e) {
      _log('signup', 'unexpected: ${e.runtimeType}: $e');
      _setLoading(false);
      throw AuthException.unknown;
    }
    _setLoading(false);
  }

  /// Sign in with Google.
  /// Throws [AuthException] or [NetworkException] on failure.
  ///
  /// No timeout: the user controls how long the interactive OAuth consent
  /// screen takes. Timing out an interactive flow is a bug, not a safety net.
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleProvider = fb.GoogleAuthProvider();
      await _firebaseAuth!.signInWithProvider(googleProvider);
      _analyticsService?.logSignIn(method: 'google');
    } on fb.FirebaseAuthException catch (e) {
      _log('google', 'FirebaseAuthException: '
          'code=${e.code}, message=${e.message}');
      _setLoading(false);
      throw _mapAuthException(e);
    } on Exception catch (e) {
      _log('google', 'unexpected: ${e.runtimeType}: $e');
      _setLoading(false);
      throw AuthException.unknown;
    }
    _setLoading(false);
  }

  /// Sign in with Apple.
  /// Throws [AuthException] or [NetworkException] on failure.
  ///
  /// No timeout: same reasoning as [signInWithGoogle].
  Future<void> signInWithApple() async {
    _setLoading(true);
    try {
      final appleProvider = fb.AppleAuthProvider();
      await _firebaseAuth!.signInWithProvider(appleProvider);
      _analyticsService?.logSignIn(method: 'apple');
    } on fb.FirebaseAuthException catch (e) {
      _log('apple', 'FirebaseAuthException: '
          'code=${e.code}, message=${e.message}');
      _setLoading(false);
      throw _mapAuthException(e);
    } on Exception catch (e) {
      _log('apple', 'unexpected: ${e.runtimeType}: $e');
      _setLoading(false);
      throw AuthException.unknown;
    }
    _setLoading(false);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _firebaseAuth!.signOut();
      await _clearPersistedData();
    } on Exception catch (e) {
      _log('signout', '$e');
    }
    _setLoading(false);
  }

  /// Update the current user's display name.
  Future<void> updateDisplayName(String name) async {
    try {
      await _firebaseAuth!.currentUser?.updateDisplayName(name);
      await _firebaseAuth.currentUser?.reload();
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        await _cacheDisplayInfo(user);
        notifyListeners();
      }
    } on Exception catch (e) {
      _log('profile', 'failed to update display name: $e');
    }
  }

  /// Delete the current user's account.
  ///
  /// Returns the deleted user's UID so the caller can clean up
  /// uid-scoped local data (SharedPreferences keys, etc.) after
  /// the auth record is gone and [currentUser] is null.
  ///
  /// Throws [AuthException.requiresRecentLogin] if Firebase demands
  /// a fresh sign-in. The caller should re-auth and retry once.
  /// Throws [AuthException.accountDeletionFailed] on other failures.
  Future<String> deleteAccount() async {
    final uid = _firebaseAuth!.currentUser?.uid;
    if (uid == null) {
      throw AuthException.accountDeletionFailed;
    }

    _setLoading(true);
    try {
      await _firebaseAuth.currentUser!
          .delete()
          .timeout(_authTimeout, onTimeout: _onTimeout);
      _analyticsService?.logAccountDelete();
      await _clearPersistedData();
    } on fb.FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'requires-recent-login') {
        throw AuthException.requiresRecentLogin;
      }
      throw AuthException.accountDeletionFailed;
    } on TimeoutException {
      _setLoading(false);
      throw const NetworkException();
    } on Exception {
      _setLoading(false);
      throw AuthException.accountDeletionFailed;
    }
    _setLoading(false);
    return uid;
  }

  /// Re-authenticate the current email/password user.
  ///
  /// Call before retrying [deleteAccount] when it throws
  /// [AuthException.requiresRecentLogin].
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth!.currentUser;
    if (user == null || user.email == null) {
      throw AuthException.accountDeletionFailed;
    }
    try {
      final credential = fb.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user
          .reauthenticateWithCredential(credential)
          .timeout(_authTimeout, onTimeout: _onTimeout);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } on TimeoutException {
      throw const NetworkException();
    }
  }

  /// Re-authenticate the current user via their OAuth provider
  /// (Google or Apple). Returns the provider ID used, or throws.
  Future<void> reauthenticateWithProvider() async {
    final user = _firebaseAuth!.currentUser;
    if (user == null) throw AuthException.accountDeletionFailed;

    final isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');
    final isApple =
        user.providerData.any((p) => p.providerId == 'apple.com');

    try {
      if (isGoogle) {
        await user.reauthenticateWithProvider(fb.GoogleAuthProvider());
      } else if (isApple) {
        await user.reauthenticateWithProvider(fb.AppleAuthProvider());
      } else {
        throw AuthException.accountDeletionFailed;
      }
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// The sign-in method of the current user, or null.
  AuthMethod? get currentAuthMethod => _currentUser?.method;

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth!
          .sendPasswordResetEmail(email: email)
          .timeout(_authTimeout, onTimeout: _onTimeout);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } on TimeoutException {
      throw const NetworkException();
    }
  }

  /// Sends a verification email to the current user.
  Future<void> sendVerificationEmail() async {
    try {
      await _firebaseAuth!.currentUser
          ?.sendEmailVerification()
          .timeout(_authTimeout, onTimeout: _onTimeout);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } on TimeoutException {
      throw const NetworkException();
    }
  }

  /// Reloads the current user from Firebase and updates local state.
  /// Returns true if the user's email is now verified.
  Future<bool> reloadAndCheckVerified() async {
    try {
      await _firebaseAuth!.currentUser
          ?.reload()
          .timeout(_authTimeout, onTimeout: _onTimeout);
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        _currentUser = _mapFirebaseUser(user);
        notifyListeners();
        return user.emailVerified;
      }
      return false;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } on TimeoutException {
      throw const NetworkException();
    }
  }

  /// Force-refreshes the ID token so Firestore rules see
  /// updated claims (e.g. email_verified after verification).
  Future<void> forceTokenRefresh() async {
    try {
      await _firebaseAuth!.currentUser?.getIdToken(true);
    } on Exception catch (e) {
      _log('token', 'force refresh failed: $e');
    }
  }

  // -- Helpers --

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Structured log for auth events. Routes to Crashlytics in production
  /// and debugPrint in debug mode. No PII in messages (error codes only).
  static void _log(String tag, String message) {
    debugPrint('AuthService [$tag] $message');
    _crashlyticsLog('AuthService [$tag] $message');
  }

  static void _crashlyticsLog(String message) {
    try {
      unawaited(FirebaseCrashlytics.instance.log(message));
    } on Exception catch (_) {
      // Crashlytics unavailable (e.g. in unit tests without Firebase).
    }
  }

  static void _setCrashlyticsUserId(String uid) {
    try {
      unawaited(FirebaseCrashlytics.instance.setUserIdentifier(uid));
    } on Exception catch (_) {
      // Crashlytics unavailable (e.g. in unit tests without Firebase).
    }
  }

  Never _onTimeout() {
    throw TimeoutException('Firebase Auth call timed out', _authTimeout);
  }

  AppException _mapAuthException(fb.FirebaseAuthException e) {
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' =>
        AuthException.invalidCredentials,
      'user-not-found' => AuthException.userNotFound,
      'email-already-in-use' => AuthException.emailAlreadyInUse,
      'weak-password' => AuthException.weakPassword,
      'too-many-requests' => AuthException.tooManyRequests,
      'network-request-failed' => const NetworkException(),
      _ => AuthException.unknown,
    };
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }
}
