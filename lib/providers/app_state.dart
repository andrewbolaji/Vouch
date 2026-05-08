import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/data/seed_data.dart';
import 'package:vouch/models/models.dart';

const bool kUseFirebase = false;

class AppState extends ChangeNotifier {
  AppState() {
    unawaited(_loadData());
  }

  static const String _votedKey = 'voted_restaurant_ids';
  static final DateTime _seedDate = DateTime(2026, 4, 27);

  List<City> _cities = [];
  List<Restaurant> _restaurants = [];
  List<Comment> _comments = [];
  final Set<String> _votedRestaurantIds = {};
  bool _isLoading = true;
  String? _searchQuery;

  // Getters
  List<City> get cities =>
      _searchQuery == null || _searchQuery!.isEmpty
          ? List.unmodifiable(_cities)
          : List.unmodifiable(
              _cities.where(
                (c) =>
                    c.name
                        .toLowerCase()
                        .contains(_searchQuery!.toLowerCase()) ||
                    c.state
                        .toLowerCase()
                        .contains(_searchQuery!.toLowerCase()),
              ),
            );

  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);
  bool get isLoading => _isLoading;
  String? get searchQuery => _searchQuery;

  List<Restaurant> restaurantsForCity(String cityId) {
    return _restaurants.where((r) => r.cityId == cityId).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  Restaurant? restaurantById(String id) {
    final matches = _restaurants.where((r) => r.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  City? cityById(String id) {
    final matches = _cities.where((c) => c.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  List<Comment> commentsForRestaurant(String restaurantId) {
    return _comments
        .where(
          (c) =>
              c.restaurantId == restaurantId &&
              c.parentId == null,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Comment> repliesForComment(String commentId) {
    return _comments
        .where((c) => c.parentId == commentId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  bool hasVoted(String restaurantId) =>
      _votedRestaurantIds.contains(restaurantId);

  // Actions
  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleVote(String restaurantId) {
    final index = _restaurants.indexWhere(
      (r) => r.id == restaurantId,
    );
    if (index == -1) return;

    final restaurant = _restaurants[index];
    if (_votedRestaurantIds.contains(restaurantId)) {
      _votedRestaurantIds.remove(restaurantId);
      _restaurants[index] = restaurant.copyWith(
        voteCount: restaurant.voteCount - 1,
      );
    } else {
      _votedRestaurantIds.add(restaurantId);
      _restaurants[index] = restaurant.copyWith(
        voteCount: restaurant.voteCount + 1,
      );
      unawaited(HapticFeedback.lightImpact());
    }
    notifyListeners();
    unawaited(_saveVotes());
  }

  Future<void> _saveVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _votedKey,
        _votedRestaurantIds.toList(),
      );
    } on Exception catch (e) {
      debugPrint('AppState: failed to save votes: $e');
    }
  }

  Future<void> _loadVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_votedKey);
      if (ids != null) {
        _votedRestaurantIds.addAll(ids);
      }
    } on Exception catch (e) {
      debugPrint('AppState: failed to load votes: $e');
    }
  }

  /// Remove voted IDs that no longer exist in
  /// current restaurant data.
  void _pruneOrphanedVotes() {
    final validIds = _restaurants.map((r) => r.id).toSet();
    final orphans = _votedRestaurantIds.difference(validIds);
    if (orphans.isNotEmpty) {
      _votedRestaurantIds.removeAll(orphans);
      debugPrint(
        'AppState: pruned ${orphans.length} '
        'orphaned vote IDs',
      );
      unawaited(_saveVotes());
    }
  }

  void addComment({
    required String restaurantId,
    required String text,
    String? parentId,
    bool isInsider = false,
  }) {
    final comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      restaurantId: restaurantId,
      userId: 'anonymous',
      userName: 'Local',
      text: text,
      createdAt: DateTime.now(),
      parentId: parentId,
      isInsider: isInsider,
    );
    _comments.add(comment);
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadData();
  }

  // Data loading
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (kUseFirebase) {
      // TODO(vouch): Load from Firebase.
    } else {
      _cities = List.from(SeedData.cities);
      _restaurants = List.from(SeedData.restaurants);
      _comments = _generateSeedComments();
    }

    await _loadVotes();
    _pruneOrphanedVotes();

    _isLoading = false;
    notifyListeners();
  }

  List<Comment> _generateSeedComments() {
    return [
      Comment(
        id: 'c1',
        restaurantId: 'hou-1',
        userId: 'user1',
        userName: 'FoodieH',
        text: 'Went on a Tuesday and only waited '
            '20 minutes. The loaded leg is insane.',
        createdAt: _seedDate,
      ),
      Comment(
        id: 'c2',
        restaurantId: 'hou-1',
        userId: 'user2',
        userName: 'HTXLocal',
        text: 'This place changed my life. '
            'Not exaggerating.',
        createdAt: DateTime(2026, 4, 20),
        isInsider: true,
      ),
      Comment(
        id: 'c3',
        restaurantId: 'nyc-1',
        userId: 'user3',
        userName: 'BKFoodie',
        text: 'Cash only caught me off guard, '
            'but the porterhouse was worth '
            'the ATM run.',
        createdAt: DateTime(2026, 4, 22),
      ),
    ];
  }
}
