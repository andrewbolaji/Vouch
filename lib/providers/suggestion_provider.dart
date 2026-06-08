import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/models/suggestion.dart';
import 'package:vouch/repositories/suggestion_repository.dart';
import 'package:vouch/services/auth_service.dart';

class SuggestionProvider extends ChangeNotifier {
  SuggestionProvider({
    required AuthService authService,
    SuggestionRepository? suggestionRepository,
  })  : _authService = authService,
        _suggestionRepo = suggestionRepository {
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthService _authService;
  final SuggestionRepository? _suggestionRepo;

  int _remaining = kDailySuggestionCap;
  bool _isSubmitting = false;

  int get remainingToday => _remaining;
  bool get canSubmitToday => _remaining > 0;
  bool get isSubmitting => _isSubmitting;

  // -- Auth reaction --

  String? get _currentUid {
    final user = _authService.currentUser;
    return (user != null && !user.isAnonymous) ? user.uid : null;
  }

  void _onAuthChanged() {
    final uid = _currentUid;
    if (uid != null) {
      unawaited(_loadRemaining(uid));
    } else {
      _remaining = kDailySuggestionCap;
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _loadRemaining(String uid) async {
    if (_suggestionRepo == null) {
      notifyListeners();
      return;
    }
    try {
      final remaining = await _suggestionRepo.getRemainingToday(uid);
      if (_currentUid != uid) return;
      _remaining = remaining;
    } on Exception catch (e) {
      debugPrint('SuggestionProvider: server load failed: $e');
      if (_currentUid != uid) return;
      await _loadFromDisk(uid);
    }
    notifyListeners();
  }

  /// Submits a suggestion via the Cloud Function.
  ///
  /// Throws [PermissionDenied] if not signed in.
  /// Throws [RateLimited] if the server rejects for daily cap.
  /// Throws [AppException] subclasses on other errors.
  Future<void> submitSuggestion({
    required SuggestionType type,
    required String text,
    String? cityId,
  }) async {
    if (!_authService.isSignedIn) {
      throw const PermissionDenied('Sign in to submit a suggestion.');
    }

    if (_suggestionRepo == null) {
      throw const FirestoreWriteException(
        'Suggestion service not available.',
      );
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      await _suggestionRepo.submit(
        type: type.name,
        text: text,
        cityId: cityId,
      );
      _remaining = (_remaining - 1).clamp(0, kDailySuggestionCap);
      final uid = _currentUid;
      if (uid != null) unawaited(_saveToDisk(uid));
    } on RateLimited {
      _remaining = 0;
      final uid = _currentUid;
      if (uid != null) unawaited(_saveToDisk(uid));
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // -- Per-uid disk cache --

  static const String _prefPrefix = 'suggestion_remaining_';

  Future<void> _loadFromDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt('$_prefPrefix$uid');
      if (cached != null) {
        _remaining = cached;
      }
    } on Exception catch (e) {
      debugPrint('SuggestionProvider: cache read failed: $e');
    }
  }

  Future<void> _saveToDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefPrefix$uid', _remaining);
    } on Exception catch (e) {
      debugPrint('SuggestionProvider: cache write failed: $e');
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
