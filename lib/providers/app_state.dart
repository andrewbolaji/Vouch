import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/data/seed_data.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/repositories/repositories.dart';

const bool kUseFirebase = true;

class AppState extends ChangeNotifier {
  AppState({
    CityRepository? cityRepo,
    RestaurantRepository? restaurantRepo,
    CommentRepository? commentRepo,
    VoteRepository? voteRepo,
    bool? useFirebase,
    bool isPaidTier = false,
    MembershipProvider? membershipProvider,
  })  : _cityRepo = cityRepo,
        _restaurantRepo = restaurantRepo,
        _commentRepo = commentRepo,
        _voteRepo = voteRepo,
        _useFirebase = useFirebase ?? kUseFirebase,
        _isPaidTier = isPaidTier,
        _membershipProvider = membershipProvider {
    _membershipProvider?.addListener(_onMembershipChanged);
    unawaited(_loadData());
  }

  final CityRepository? _cityRepo;
  final RestaurantRepository? _restaurantRepo;
  final CommentRepository? _commentRepo;
  final VoteRepository? _voteRepo;
  final bool _useFirebase;
  final MembershipProvider? _membershipProvider;
  bool _isPaidTier;

  static const String _votedKey = 'voted_restaurant_ids';
  static final DateTime _seedDate = DateTime(2026, 4, 27);

  List<City> _cities = [];
  List<Restaurant> _restaurants = [];
  List<Comment> _comments = [];
  final Set<String> _votedRestaurantIds = {};
  bool _isLoading = true;
  bool _isOffline = false;
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
  bool get isOffline => _isOffline;
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

  void _onMembershipChanged() {
    final newPaid = _membershipProvider?.canViewTop10 ?? false;
    if (newPaid != _isPaidTier) {
      unawaited(refresh(isPaidTier: newPaid));
    }
  }

  @override
  void dispose() {
    _membershipProvider?.removeListener(_onMembershipChanged);
    super.dispose();
  }

  // Actions
  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Toggles a vote for the given restaurant.
  ///
  /// [userId] must be the signed-in user's UID. The caller is
  /// responsible for gating on sign-in state before calling this.
  void toggleVote(String restaurantId, {required String userId}) {
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
      if (_useFirebase && _voteRepo != null) {
        unawaited(_voteRepo.unvote(restaurantId, userId));
      }
    } else {
      _votedRestaurantIds.add(restaurantId);
      _restaurants[index] = restaurant.copyWith(
        voteCount: restaurant.voteCount + 1,
      );
      unawaited(HapticFeedback.lightImpact());
      if (_useFirebase && _voteRepo != null) {
        unawaited(_voteRepo.vote(restaurantId, userId));
      }
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
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to save votes: $e');
      _recordError('_saveVotes', e, stack);
    }
  }

  Future<void> _loadVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_votedKey);
      if (ids != null) {
        _votedRestaurantIds.addAll(ids);
      }
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to load votes: $e');
      _recordError('_loadVotes', e, stack);
    }
  }

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

    if (_useFirebase && _commentRepo != null) {
      unawaited(
        _commentRepo.add(restaurantId, comment),
      );
    }
  }

  /// Reload data. Call after sign-in or membership change so the
  /// query uses the correct tier gate.
  Future<void> refresh({bool? isPaidTier}) async {
    if (isPaidTier != null) _isPaidTier = isPaidTier;
    await _loadData();
  }

  // Data loading
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    if (_useFirebase) {
      await _loadFromFirestore();
    } else {
      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );
      _cities = List.from(SeedData.cities);
      _restaurants = List.from(SeedData.restaurants);
      _comments = _generateSeedComments();
      _applySeedCommentCounts();
    }

    await _loadVotes();
    _pruneOrphanedVotes();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final cityRepo = _cityRepo ?? CityRepository();
      final restaurantRepo = _restaurantRepo ?? RestaurantRepository();

      _cities = await cityRepo.getCities();
      _restaurants = [];
      for (final city in _cities) {
        final cityRestaurants = await restaurantRepo.getForCity(
          city.id,
          canViewTop10: _isPaidTier,
        );
        _restaurants.addAll(cityRestaurants);
      }
      _isOffline = false;
    } on Exception catch (e, stack) {
      debugPrint('AppState: Firestore load failed: $e');
      _recordError('_loadFromFirestore', e, stack);
      _isOffline = true;
      // Fall back to seed data on failure
      _cities = List.from(SeedData.cities);
      _restaurants = List.from(SeedData.restaurants);
      _comments = _generateSeedComments();
      _applySeedCommentCounts();
    }
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

  static void _recordError(String reason, Object error, StackTrace stack) {
    try {
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'AppState: $reason',
      ));
    } on Exception catch (_) {
      // Crashlytics unavailable (unit tests).
    }
  }

  /// Sets commentCount on each seed restaurant to match the number of
  /// seed comments for that restaurant. Counts ALL comments including
  /// replies, mirroring the Firestore backfill which counts every doc
  /// in the subcollection without excluding replies.
  void _applySeedCommentCounts() {
    final counts = <String, int>{};
    for (final c in _comments) {
      counts[c.restaurantId] = (counts[c.restaurantId] ?? 0) + 1;
    }
    for (var i = 0; i < _restaurants.length; i++) {
      final count = counts[_restaurants[i].id];
      if (count != null && count > 0) {
        _restaurants[i] = _restaurants[i].copyWith(commentCount: count);
      }
    }
  }
}
