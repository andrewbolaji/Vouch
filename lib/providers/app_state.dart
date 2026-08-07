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

/// Where a restaurant's comment page is in its load lifecycle.
///
/// notLoaded and loading are distinct from loaded-with-zero-comments,
/// so a restaurant that genuinely has no comments never looks the
/// same as one that simply has not been fetched yet.
enum CommentLoadStatus { notLoaded, loading, loaded, error }

/// One restaurant's loaded comment page, replies, and pagination
/// cursor. Backs the online (Firestore) comment read path only; the
/// offline/seed comment list is separate, see AppState._usingSeedComments.
class RestaurantCommentsState {
  const RestaurantCommentsState.notLoaded()
      : status = CommentLoadStatus.notLoaded,
        comments = const [],
        repliesByCommentId = const {},
        nextCursor = null,
        errorMessage = null,
        isLoadingMore = false;

  const RestaurantCommentsState.loading()
      : status = CommentLoadStatus.loading,
        comments = const [],
        repliesByCommentId = const {},
        nextCursor = null,
        errorMessage = null,
        isLoadingMore = false;

  const RestaurantCommentsState.loaded({
    required this.comments,
    required this.repliesByCommentId,
    this.nextCursor,
    this.isLoadingMore = false,
  })  : status = CommentLoadStatus.loaded,
        errorMessage = null;

  const RestaurantCommentsState.error(this.errorMessage)
      : status = CommentLoadStatus.error,
        comments = const [],
        repliesByCommentId = const {},
        nextCursor = null,
        isLoadingMore = false;

  final CommentLoadStatus status;
  final List<Comment> comments;
  final Map<String, List<Comment>> repliesByCommentId;
  final String? nextCursor;
  final String? errorMessage;
  final bool isLoadingMore;
}

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

  /// Offline/seed comments only. Populated by _generateSeedComments
  /// when Firestore is unreachable or useFirebase is false. The
  /// online read path uses _restaurantComments instead.
  List<Comment> _comments = [];
  final Map<String, RestaurantCommentsState> _restaurantComments = {};
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

  /// True while comments come from the offline/seed fallback rather
  /// than a real per-restaurant Firestore fetch: either useFirebase
  /// is false (tests), or the initial cities/restaurants load failed
  /// and _loadFromFirestore fell back to seed data.
  bool get _usingSeedComments => !_useFirebase || _isOffline;

  List<Comment> commentsForRestaurant(String restaurantId) {
    if (_usingSeedComments) {
      return _comments
          .where(
            (c) =>
                c.restaurantId == restaurantId &&
                c.parentId == null,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return List.unmodifiable(
      _restaurantComments[restaurantId]?.comments ?? const [],
    );
  }

  /// [restaurantId] is required for the online path (replies are
  /// stored per restaurant) but optional for backward compatibility
  /// with the offline/seed path, which only ever needed the comment id.
  List<Comment> repliesForComment(String commentId, [String? restaurantId]) {
    if (_usingSeedComments) {
      return _comments
          .where((c) => c.parentId == commentId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    if (restaurantId != null) {
      return List.unmodifiable(
        _restaurantComments[restaurantId]?.repliesByCommentId[commentId] ??
            const [],
      );
    }
    for (final state in _restaurantComments.values) {
      final replies = state.repliesByCommentId[commentId];
      if (replies != null) return List.unmodifiable(replies);
    }
    return const [];
  }

  /// Where restaurantId's comment page is in its load lifecycle.
  /// Always "loaded" for the offline/seed fallback, since seed
  /// comments are already synchronously available.
  CommentLoadStatus commentsStatus(String restaurantId) {
    if (_usingSeedComments) return CommentLoadStatus.loaded;
    return _restaurantComments[restaurantId]?.status ??
        CommentLoadStatus.notLoaded;
  }

  /// Message for the last failed comment load, if commentsStatus is error.
  String? commentsError(String restaurantId) =>
      _restaurantComments[restaurantId]?.errorMessage;

  /// True if another page of comments is available to load.
  bool hasMoreComments(String restaurantId) {
    if (_usingSeedComments) return false;
    return _restaurantComments[restaurantId]?.nextCursor != null;
  }

  /// True while a load-more request for restaurantId is in flight.
  bool isLoadingMoreComments(String restaurantId) =>
      _restaurantComments[restaurantId]?.isLoadingMore ?? false;

  /// Loads the first page of comments (and their replies) for
  /// restaurantId. Safe to call every time a screen opens: does
  /// nothing once a page is already loaded or already loading, so
  /// re-entering a screen does not refetch what is already there.
  Future<void> loadCommentsForRestaurant(String restaurantId) async {
    if (_usingSeedComments) return;
    final existing = _restaurantComments[restaurantId];
    if (existing != null &&
        (existing.status == CommentLoadStatus.loaded ||
            existing.status == CommentLoadStatus.loading)) {
      return;
    }

    _restaurantComments[restaurantId] =
        const RestaurantCommentsState.loading();
    notifyListeners();

    try {
      final repo = _commentRepo ?? CommentRepository();
      final page = await repo.getPage(restaurantId);
      final repliesByCommentId = await _fetchRepliesFor(
        repo,
        restaurantId,
        page.comments,
      );

      _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
        comments: page.comments,
        repliesByCommentId: repliesByCommentId,
        nextCursor: page.nextCursor,
      );
    } on Exception catch (e, stack) {
      _recordError('loadCommentsForRestaurant', e, stack);
      _restaurantComments[restaurantId] = RestaurantCommentsState.error(
        e.toString(),
      );
    }
    notifyListeners();
  }

  /// Loads the next page of comments for restaurantId, appending to
  /// what is already loaded. No-op if there is no next page, if a
  /// load is already in flight, or if the first page has not loaded.
  Future<void> loadMoreComments(String restaurantId) async {
    if (_usingSeedComments) return;
    final existing = _restaurantComments[restaurantId];
    if (existing == null ||
        existing.status != CommentLoadStatus.loaded ||
        existing.nextCursor == null ||
        existing.isLoadingMore) {
      return;
    }

    _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
      comments: existing.comments,
      repliesByCommentId: existing.repliesByCommentId,
      nextCursor: existing.nextCursor,
      isLoadingMore: true,
    );
    notifyListeners();

    try {
      final repo = _commentRepo ?? CommentRepository();
      final page = await repo.getPage(
        restaurantId,
        cursor: existing.nextCursor,
      );
      final newReplies = await _fetchRepliesFor(
        repo,
        restaurantId,
        page.comments,
      );
      final current = _restaurantComments[restaurantId]!;

      _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
        comments: [...current.comments, ...page.comments],
        repliesByCommentId: {...current.repliesByCommentId, ...newReplies},
        nextCursor: page.nextCursor,
      );
    } on Exception catch (e, stack) {
      _recordError('loadMoreComments', e, stack);
      final current = _restaurantComments[restaurantId];
      if (current != null) {
        _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
          comments: current.comments,
          repliesByCommentId: current.repliesByCommentId,
          nextCursor: current.nextCursor,
        );
      }
    }
    notifyListeners();
  }

  /// Fetches replies for each of [comments] in parallel. At a page
  /// size of 20 that is at most 20 small queries per screen open,
  /// negligible at launch volume. A failed reply fetch for one
  /// comment does not fail the rest; it just shows that comment with
  /// no replies rather than erroring the whole page.
  ///
  /// v1.1: a replyCount field maintained by onCommentCreated would
  /// let the client skip this call entirely for comments with none.
  Future<Map<String, List<Comment>>> _fetchRepliesFor(
    CommentRepository repo,
    String restaurantId,
    List<Comment> comments,
  ) async {
    final repliesLists = await Future.wait(
      comments.map((c) async {
        try {
          return await repo.getReplies(restaurantId, c.id);
        } on Exception {
          return const <Comment>[];
        }
      }),
    );
    return {
      for (var i = 0; i < comments.length; i++)
        comments[i].id: repliesLists[i],
    };
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
    if (_usingSeedComments) {
      _comments.add(comment);
    } else {
      final existing = _restaurantComments[restaurantId] ??
          const RestaurantCommentsState.loaded(
            comments: [],
            repliesByCommentId: {},
          );
      if (parentId == null) {
        // getPage orders createdAt descending, so the newest comment
        // goes at index 0, not the end.
        _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
          comments: [comment, ...existing.comments],
          repliesByCommentId: existing.repliesByCommentId,
          nextCursor: existing.nextCursor,
          isLoadingMore: existing.isLoadingMore,
        );
      } else {
        // getReplies orders createdAt ascending, so the newest reply
        // goes at the end of its parent's list.
        final updatedReplies = Map<String, List<Comment>>.from(
          existing.repliesByCommentId,
        );
        updatedReplies[parentId] = [
          ...(updatedReplies[parentId] ?? const []),
          comment,
        ];
        _restaurantComments[restaurantId] = RestaurantCommentsState.loaded(
          comments: existing.comments,
          repliesByCommentId: updatedReplies,
          nextCursor: existing.nextCursor,
          isLoadingMore: existing.isLoadingMore,
        );
      }
    }
    _bumpCommentCount(restaurantId);
    notifyListeners();

    if (_useFirebase && _commentRepo != null) {
      unawaited(
        _commentRepo.add(restaurantId, comment),
      );
    }
  }

  /// Bumps commentCount locally so the header does not lag behind
  /// an optimistically-added comment while waiting for the real
  /// server aggregate to catch up.
  void _bumpCommentCount(String restaurantId) {
    final index = _restaurants.indexWhere((r) => r.id == restaurantId);
    if (index == -1) return;
    _restaurants[index] = _restaurants[index].copyWith(
      commentCount: _restaurants[index].commentCount + 1,
    );
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
