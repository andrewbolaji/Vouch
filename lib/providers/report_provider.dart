import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/models/report.dart';
import 'package:vouch/repositories/report_repository.dart';
import 'package:vouch/services/auth_service.dart';

/// Provider for submitting comment reports.
///
/// Mirrors the SuggestionProvider pattern: auth-reactive, rate-limited,
/// with a daily cap.
class ReportProvider extends ChangeNotifier {
  ReportProvider({
    required AuthService authService,
    ReportRepository? reportRepository,
  })  : _authService = authService,
        _reportRepo = reportRepository {
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthService _authService;
  final ReportRepository? _reportRepo;

  int _remaining = kDailyReportCap;
  bool _isSubmitting = false;

  int get remainingToday => _remaining;
  bool get canReport => _remaining > 0;
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
      _remaining = kDailyReportCap;
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _loadRemaining(String uid) async {
    if (_reportRepo == null) {
      notifyListeners();
      return;
    }
    try {
      final remaining = await _reportRepo.getRemainingToday(uid);
      if (_currentUid != uid) return;
      _remaining = remaining;
    } on Exception catch (e) {
      debugPrint('ReportProvider: server load failed: $e');
      if (_currentUid != uid) return;
    }
    notifyListeners();
  }

  /// Submits a report for a comment.
  ///
  /// Throws [PermissionDenied] if not signed in.
  /// Throws [RateLimited] if the daily cap is reached.
  Future<void> submitReport({
    required String commentId,
    required String commentPath,
    required String restaurantId,
    required String cityId,
    required ReportReason reason,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      throw const PermissionDenied('Sign in to report a comment.');
    }
    if (_reportRepo == null) {
      throw const FirestoreWriteException('Report service not available.');
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      await _reportRepo.submit(
        reporterUid: uid,
        commentId: commentId,
        commentPath: commentPath,
        restaurantId: restaurantId,
        cityId: cityId,
        reason: reason,
      );
      _remaining = (_remaining - 1).clamp(0, kDailyReportCap);
    } on RateLimited {
      _remaining = 0;
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
