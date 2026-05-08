import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedProvider extends ChangeNotifier {
  SavedProvider() {
    unawaited(_loadFromDisk());
  }

  static const String _prefKey = 'saved_restaurant_ids';

  final Set<String> _savedRestaurantIds = {};
  bool _loaded = false;

  Set<String> get savedRestaurantIds =>
      Set.unmodifiable(_savedRestaurantIds);
  bool get isLoaded => _loaded;

  bool isSaved(String restaurantId) =>
      _savedRestaurantIds.contains(restaurantId);

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefKey);
      if (ids != null) {
        _savedRestaurantIds.addAll(ids);
      }
    } on Exception catch (e) {
      debugPrint('SavedProvider: failed to load: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefKey,
        _savedRestaurantIds.toList(),
      );
    } on Exception catch (e) {
      debugPrint('SavedProvider: failed to save: $e');
    }
  }

  void toggleSaved(String restaurantId) {
    if (_savedRestaurantIds.contains(restaurantId)) {
      _savedRestaurantIds.remove(restaurantId);
    } else {
      _savedRestaurantIds.add(restaurantId);
      unawaited(HapticFeedback.lightImpact());
    }
    notifyListeners();
    unawaited(_saveToDisk());
  }

  /// Count of saved IDs that exist in the given set
  /// of valid restaurant IDs. Use this for display
  /// to avoid showing orphaned counts.
  int savedCountFor(Set<String> validIds) {
    return _savedRestaurantIds
        .where(validIds.contains)
        .length;
  }

  int get savedCount => _savedRestaurantIds.length;

  /// Remove IDs that no longer exist in the current
  /// restaurant data. Call after data loads.
  void pruneOrphans(Set<String> validIds) {
    final orphans = _savedRestaurantIds
        .difference(validIds);
    if (orphans.isNotEmpty) {
      _savedRestaurantIds.removeAll(orphans);
      debugPrint(
        'SavedProvider: pruned ${orphans.length} '
        'orphaned IDs',
      );
      notifyListeners();
      unawaited(_saveToDisk());
    }
  }
}
