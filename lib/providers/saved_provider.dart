import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/services/auth_service.dart';

class SavedProvider extends ChangeNotifier {
  SavedProvider({
    required AuthService authService,
    UserRepository? userRepository,
  })  : _authService = authService,
        _userRepo = userRepository {
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthService _authService;
  final UserRepository? _userRepo;

  final Set<String> _savedRestaurantIds = {};
  bool _loaded = false;

  Set<String> get savedRestaurantIds =>
      Set.unmodifiable(_savedRestaurantIds);
  bool get isLoaded => _loaded;

  bool isSaved(String restaurantId) =>
      _savedRestaurantIds.contains(restaurantId);

  int get savedCount => _savedRestaurantIds.length;

  int savedCountFor(Set<String> validIds) {
    return _savedRestaurantIds.where(validIds.contains).length;
  }

  void pruneOrphans(Set<String> validIds) {
    final orphans = _savedRestaurantIds.difference(validIds);
    if (orphans.isNotEmpty) {
      _savedRestaurantIds.removeAll(orphans);
      debugPrint(
        'SavedProvider: pruned ${orphans.length} orphaned IDs',
      );
      notifyListeners();
      final uid = _currentUid;
      if (uid != null) unawaited(_cacheToDisk(uid));
    }
  }

  // -- Auth reaction --

  String? get _currentUid {
    final user = _authService.currentUser;
    return (user != null && !user.isAnonymous) ? user.uid : null;
  }

  void _onAuthChanged() {
    final uid = _currentUid;
    if (uid != null) {
      unawaited(_ensureUserDocAndLoad(uid));
    } else {
      _savedRestaurantIds.clear();
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _ensureUserDocAndLoad(String uid) async {
    if (_userRepo != null) {
      try {
        final user = _authService.currentUser;
        await _userRepo.ensureUserDoc(
          uid: uid,
          displayName: user?.displayName ?? '',
          email: user?.email ?? '',
        );
      } on Exception catch (e) {
        debugPrint('SavedProvider: ensureUserDoc failed: $e');
      }
    }
    await _loadForUser(uid);
  }

  Future<void> _loadForUser(String uid) async {
    if (_userRepo == null) {
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final ids = await _userRepo.getSavedIds(uid);
      if (_currentUid != uid) return;
      _savedRestaurantIds
        ..clear()
        ..addAll(ids);
      unawaited(_cacheToDisk(uid));
    } on Exception catch (e) {
      debugPrint('SavedProvider: server load failed: $e');
      if (_currentUid != uid) return;
      await _loadFromDisk(uid);
    }
    _loaded = true;
    notifyListeners();
  }

  // -- Save toggle with optimistic rollback --

  /// Toggles the saved state for [restaurantId].
  ///
  /// Returns null on success, or the [AppException] on failure
  /// after rolling back the optimistic update.
  Future<AppException?> toggleSaved(String restaurantId) async {
    final uid = _currentUid;
    if (uid == null) {
      return const PermissionDenied('Sign in to save restaurants.');
    }

    final adding = !_savedRestaurantIds.contains(restaurantId);

    if (adding) {
      _savedRestaurantIds.add(restaurantId);
      unawaited(HapticFeedback.lightImpact());
    } else {
      _savedRestaurantIds.remove(restaurantId);
    }
    notifyListeners();

    if (_userRepo == null) return null;
    try {
      await _userRepo.updateSaved(uid, restaurantId, add: adding);
      unawaited(_cacheToDisk(uid));
      return null;
    } on AppException catch (e) {
      // Rollback
      if (adding) {
        _savedRestaurantIds.remove(restaurantId);
      } else {
        _savedRestaurantIds.add(restaurantId);
      }
      notifyListeners();
      return e;
    }
  }

  // -- Per-uid disk cache (offline fallback) --

  String _cacheKey(String uid) => 'saved_restaurant_ids_$uid';

  Future<void> _cacheToDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _cacheKey(uid),
        _savedRestaurantIds.toList(),
      );
    } on Exception catch (e) {
      debugPrint('SavedProvider: cache write failed: $e');
    }
  }

  Future<void> _loadFromDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_cacheKey(uid));
      if (ids != null) {
        _savedRestaurantIds
          ..clear()
          ..addAll(ids);
      }
    } on Exception catch (e) {
      debugPrint('SavedProvider: cache read failed: $e');
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}
