import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/data/seed_data.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/repositories/repositories.dart';
import 'package:vouch/services/auth_service.dart';

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

/// Where a restaurant's insider notes are in their load lifecycle.
///
/// `loadedEmpty` is deliberately distinct from `loaded`. An entitled
/// user looking at a restaurant Andrew has not written about yet is
/// not an error and is not a paywall, and collapsing those states is
/// what made finding 2 invisible for three months.
enum InsiderNotesStatus { notLoaded, loading, loaded, loadedEmpty, error }

/// One restaurant's insider notes and their load state.
class InsiderNotesState {
  const InsiderNotesState.notLoaded()
      : status = InsiderNotesStatus.notLoaded,
        notes = null,
        errorMessage = null;

  const InsiderNotesState.loading()
      : status = InsiderNotesStatus.loading,
        notes = null,
        errorMessage = null;

  const InsiderNotesState.loaded(InsiderNotes this.notes)
      : status = InsiderNotesStatus.loaded,
        errorMessage = null;

  /// The entitled user read successfully and there is nothing written.
  const InsiderNotesState.empty()
      : status = InsiderNotesStatus.loadedEmpty,
        notes = null,
        errorMessage = null;

  const InsiderNotesState.error(this.errorMessage)
      : status = InsiderNotesStatus.error,
        notes = null;

  final InsiderNotesStatus status;
  final InsiderNotes? notes;
  final String? errorMessage;

  /// True only when there is something written to show.
  bool get hasNotes =>
      status == InsiderNotesStatus.loaded &&
      ((notes?.insiderTip ?? '').trim().isNotEmpty ||
          (notes?.whatToOrder ?? '').trim().isNotEmpty);
}

class AppState extends ChangeNotifier {
  AppState({
    CityRepository? cityRepo,
    RestaurantRepository? restaurantRepo,
    CommentRepository? commentRepo,
    VoteRepository? voteRepo,
    UserRepository? userRepo,
    bool? useFirebase,
    bool isPaidTier = false,
    MembershipProvider? membershipProvider,
    AuthService? authService,
  })  : _cityRepo = cityRepo,
        _restaurantRepo = restaurantRepo,
        _commentRepo = commentRepo,
        _voteRepo = voteRepo,
        _userRepo = userRepo,
        _useFirebase = useFirebase ?? kUseFirebase,
        _isPaidTier = isPaidTier,
        _membershipProvider = membershipProvider,
        _authService = authService {
    _membershipProvider?.addListener(_onMembershipChanged);
    _lastKnownUid = _authService?.currentUser?.uid;
    _authService?.addListener(_onAuthChanged);
    unawaited(_loadData());
  }

  final CityRepository? _cityRepo;
  final RestaurantRepository? _restaurantRepo;
  final CommentRepository? _commentRepo;
  final VoteRepository? _voteRepo;
  final UserRepository? _userRepo;
  final bool _useFirebase;
  final MembershipProvider? _membershipProvider;
  final AuthService? _authService;
  bool _isPaidTier;

  // The uid votes were last reconciled against. Null means either
  // signed out, or never reconciled this session. Guards against
  // reconciling the same user's votes on every unrelated
  // notifyListeners() tick from AuthService.
  String? _reconciledVotesUid;

  /// The uid AuthService last reported, tracked independently of
  /// reconciliation so sign-out can clear this device's cache in
  /// every mode, including the ones where reconciliation never runs.
  String? _lastKnownUid;

  /// Legacy, un-scoped vote cache key. Deleted on sight rather than
  /// migrated: it is shared across every account that has ever
  /// signed in on the device, which is the leak the uid-scoped key
  /// below exists to close, so carrying its contents forward would
  /// carry the leak forward too.
  static const String _legacyVotedKey = 'voted_restaurant_ids';

  /// Per-uid vote cache key, matching saved_restaurant_ids_$uid and
  /// suggestion_remaining_$uid (docs/DECISIONS.md, 2026-06-07:
  /// "Never read cross-user, never merged"). Votes were the one
  /// member of that family left un-scoped, so a signed-out user saw
  /// the previous account's votes and two accounts on one device
  /// shared a cache. Same class of leak as the finding 7 rule, one
  /// layer down.
  static String _votedKeyFor(String uid) => 'voted_restaurant_ids_$uid';

  static final DateTime _seedDate = DateTime(2026, 4, 27);

  List<City> _cities = [];
  List<Restaurant> _restaurants = [];

  /// Offline/seed comments only. Populated by _generateSeedComments
  /// when Firestore is unreachable or useFirebase is false. The
  /// online read path uses _restaurantComments instead.
  List<Comment> _comments = [];
  final Map<String, RestaurantCommentsState> _restaurantComments = {};
  final Map<String, InsiderNotesState> _insiderNotes = {};
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

  List<Comment> repliesForComment(
    String commentId, {
    required String restaurantId,
  }) {
    if (_usingSeedComments) {
      return _comments
          .where((c) => c.parentId == commentId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return List.unmodifiable(
      _restaurantComments[restaurantId]?.repliesByCommentId[commentId] ??
          const [],
    );
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
  /// The insider notes load state for one restaurant.
  InsiderNotesState insiderNotesFor(String restaurantId) =>
      _insiderNotes[restaurantId] ?? const InsiderNotesState.notLoaded();

  /// Loads insider notes for one restaurant, on demand.
  ///
  /// Only call this for a user who is entitled. firestore.rules gates
  /// the insiderNotes subcollection on isCityInsider(), so a free
  /// user's read is denied at the server, and firing it anyway would
  /// spend a round trip to learn something the client already knows
  /// from its own claim.
  ///
  /// That gate is also why the free user's branch cannot be driven by
  /// this data at all: a free client cannot discover whether notes
  /// exist without being told, and a `hasInsiderNotes` flag on the
  /// public document is exactly the leak the subcollection exists to
  /// prevent. The screen renders the free branch from the entitlement
  /// instead, the same shape as the locked rows in finding 11.
  Future<void> loadInsiderNotesForRestaurant(String restaurantId) async {
    if (!_useFirebase) return;

    final existing = _insiderNotes[restaurantId];
    if (existing != null &&
        (existing.status == InsiderNotesStatus.loading ||
            existing.status == InsiderNotesStatus.loaded ||
            existing.status == InsiderNotesStatus.loadedEmpty)) {
      return;
    }

    _insiderNotes[restaurantId] = const InsiderNotesState.loading();
    notifyListeners();

    try {
      final repo = _restaurantRepo ?? RestaurantRepository();
      final notes = await repo.getInsiderNotes(restaurantId);
      // A missing subdocument and a subdocument with two blank
      // strings are the same thing to a reader, so both resolve to
      // empty rather than one of them rendering blank headings.
      final hasContent = notes != null &&
          ((notes.insiderTip ?? '').trim().isNotEmpty ||
              (notes.whatToOrder ?? '').trim().isNotEmpty);
      _insiderNotes[restaurantId] = hasContent
          ? InsiderNotesState.loaded(notes)
          : const InsiderNotesState.empty();
    } on Exception catch (e, stack) {
      _recordError('loadInsiderNotesForRestaurant', e, stack);
      _insiderNotes[restaurantId] = InsiderNotesState.error(e.toString());
    }
    notifyListeners();
  }

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

  /// Reconciles local vote state against the server whenever a new
  /// user becomes signed in, so a returning user on a new device
  /// sees their real votes instead of an empty local cache, and a
  /// user whose write once failed and rolled back does not keep
  /// seeing a vote that Firestore does not have.
  ///
  /// Only fires on an actual uid change, not every AuthService
  /// notification (loading-state flips, token refreshes), and only
  /// once restaurants have loaded, since reconciliation has nothing
  /// to check votes against before then. The post-load case (already
  /// signed in when AppState is constructed) is handled at the end of
  /// _loadData instead, since this listener only sees changes, not
  /// the initial state.
  void _onAuthChanged() {
    final uid = _authService?.currentUser?.uid;
    // Tracked separately from _reconciledVotesUid on purpose. Sign-out
    // must clear this device's cache whether or not a server
    // reconciliation ever ran: reconciliation is skipped entirely
    // when useFirebase is false, so keying the clear off it would
    // leave the previous account's votes on screen and on disk in
    // exactly the offline and seed cases where nothing else would
    // overwrite them.
    if (uid == _lastKnownUid) return;
    final previousUid = _lastKnownUid;
    _lastKnownUid = uid;

    if (uid == null) {
      _reconciledVotesUid = null;
      if (previousUid != null) {
        unawaited(_clearVotesForSignOut(previousUid));
      }
      return;
    }
    if (uid == _reconciledVotesUid || _isLoading) return;
    _reconciledVotesUid = uid;
    unawaited(_reconcileVotesFromServer(uid));
  }

  /// Replaces local vote state with the server's own list for
  /// [userId]. Server authoritative, matching how SavedProvider
  /// treats saved restaurants on sign-in (docs/DECISIONS.md,
  /// 2026-06-07): replace, not merge, so a vote removed on another
  /// device or rolled back after a failed write does not survive.
  ///
  /// One document read, users/{uid}, not one read per restaurant.
  /// The field is maintained by the vote triggers via the Admin SDK
  /// and is denied to client writes by firestore.rules.
  ///
  /// This list can be wrong, not merely stale: arrayUnion and
  /// arrayRemove are idempotent under redelivery but not
  /// order-independent, and Firestore trigger delivery is unordered,
  /// so a fast vote then unvote whose events land reversed converges
  /// to "voted" when the truth is "not voted".
  /// [repairVoteStateForRestaurant] is what corrects that, per
  /// restaurant, at the moment the user can actually see it.
  Future<void> _reconcileVotesFromServer(String userId) async {
    try {
      final userRepo = _userRepo ?? UserRepository();
      final serverVoted = await userRepo.getVotedIds(userId);
      _votedRestaurantIds
        ..clear()
        ..addAll(serverVoted);
      unawaited(_saveVotes());
      notifyListeners();
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to reconcile votes from server: $e');
      _recordError('_reconcileVotesFromServer', e, stack);
      // Leave local state as-is. A failed reconciliation should not
      // wipe out what the user already sees; only a successful one
      // replaces it.
    }
  }

  /// Corrects the cached vote state for one restaurant against the
  /// authoritative votes subcollection, using a single scoped get of
  /// the caller's own vote document.
  ///
  /// Called when a restaurant's detail screen opens, which is the
  /// only place the vote button is rendered, so this repairs exactly
  /// the entry the user is about to look at and act on.
  ///
  /// This is load-bearing, not cosmetic. If the cached list wrongly
  /// says not-voted, the button invites a tap; VoteRepository.vote
  /// then writes to a vote document that already exists, which
  /// firestore.rules classifies as an update, and updates on that
  /// path are denied outright. Without this repair the user is stuck
  /// in a repeating error on a restaurant they already voted for,
  /// with no way to reach the delete that would clear it.
  Future<void> repairVoteStateForRestaurant(String restaurantId) async {
    if (!_useFirebase || _voteRepo == null) return;
    final uid = _authService?.currentUser?.uid;
    if (uid == null) return;
    try {
      final serverVoted = await _voteRepo.hasVoted(restaurantId, uid);
      final localVoted = _votedRestaurantIds.contains(restaurantId);
      if (serverVoted == localVoted) return;
      if (serverVoted) {
        _votedRestaurantIds.add(restaurantId);
      } else {
        _votedRestaurantIds.remove(restaurantId);
      }
      unawaited(_saveVotes());
      notifyListeners();
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to repair vote state: $e');
      _recordError('repairVoteStateForRestaurant', e, stack);
    }
  }

  @override
  void dispose() {
    _membershipProvider?.removeListener(_onMembershipChanged);
    _authService?.removeListener(_onAuthChanged);
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
  ///
  /// Flips local state immediately (optimistic, so the button
  /// responds without waiting on the network), then awaits the
  /// Firestore write. If that write fails, the optimistic flip is
  /// rolled back, so _votedRestaurantIds and SharedPreferences can
  /// never disagree with what Firestore actually has, and rethrows
  /// so the caller can show it: a failed vote must not leave the
  /// button filled in, matching how addComment already treats a
  /// failed write as the caller's problem to surface, not something
  /// to swallow here.
  Future<void> toggleVote(
    String restaurantId, {
    required String userId,
  }) async {
    final index = _restaurants.indexWhere(
      (r) => r.id == restaurantId,
    );
    if (index == -1) return;

    final restaurant = _restaurants[index];
    final wasVoted = _votedRestaurantIds.contains(restaurantId);

    if (wasVoted) {
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

    if (!_useFirebase || _voteRepo == null) return;

    try {
      if (wasVoted) {
        await _voteRepo.unvote(restaurantId, userId);
      } else {
        await _voteRepo.vote(restaurantId, userId);
      }
    } on Exception catch (e, stack) {
      // Roll back. Re-look-up the index: _restaurants may have been
      // replaced by a refresh() while this write was in flight.
      final currentIndex = _restaurants.indexWhere(
        (r) => r.id == restaurantId,
      );
      if (wasVoted) {
        _votedRestaurantIds.add(restaurantId);
        if (currentIndex != -1) {
          _restaurants[currentIndex] = _restaurants[currentIndex].copyWith(
            voteCount: _restaurants[currentIndex].voteCount + 1,
          );
        }
      } else {
        _votedRestaurantIds.remove(restaurantId);
        if (currentIndex != -1) {
          _restaurants[currentIndex] = _restaurants[currentIndex].copyWith(
            voteCount: _restaurants[currentIndex].voteCount - 1,
          );
        }
      }
      notifyListeners();
      unawaited(_saveVotes());
      _recordError('toggleVote', e, stack);
      rethrow;
    }
  }

  Future<void> _saveVotes() async {
    final uid = _authService?.currentUser?.uid;
    // Signed out means there is no owner to file these under. A vote
    // requires a signed-in uid to exist at all, so there is nothing
    // legitimate to persist here.
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _votedKeyFor(uid),
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
      // Drop the legacy shared key wherever it is still on disk,
      // whether or not anyone is signed in right now.
      if (prefs.containsKey(_legacyVotedKey)) {
        await prefs.remove(_legacyVotedKey);
      }
      final uid = _authService?.currentUser?.uid;
      if (uid == null) return;
      final ids = prefs.getStringList(_votedKeyFor(uid));
      if (ids != null) {
        _votedRestaurantIds.addAll(ids);
      }
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to load votes: $e');
      _recordError('_loadVotes', e, stack);
    }
  }

  /// Clears this device's cached vote state for the signed-out user.
  ///
  /// Both halves matter: the stored key so the next account on this
  /// device cannot read it, and the in-memory set so the buttons
  /// stop showing the previous account's votes without waiting for a
  /// reload. Clearing only the key, which is what account deletion
  /// used to do, leaves the filled-in buttons on screen.
  Future<void> _clearVotesForSignOut(String uid) async {
    _votedRestaurantIds.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_votedKeyFor(uid));
    } on Exception catch (e, stack) {
      debugPrint('AppState: failed to clear votes on sign-out: $e');
      _recordError('_clearVotesForSignOut', e, stack);
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

  /// Submits a comment (or, if [parentId] is set, a reply).
  ///
  /// In the offline/seed fallback, the comment is fabricated locally
  /// since there is no server to ask. Otherwise this awaits the
  /// `submitComment` callable and only appends the comment it
  /// returns: unlike a direct Firestore write, a callable cannot
  /// queue while offline, so a failure here is a real failure and is
  /// left for the caller to catch and show.
  Future<void> addComment({
    required String restaurantId,
    required String text,
    String? parentId,
    bool isInsider = false,
  }) async {
    if (_usingSeedComments) {
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
      _bumpCommentCount(restaurantId);
      notifyListeners();
      return;
    }

    final repo = _commentRepo ?? CommentRepository();
    final comment = await repo.submitComment(
      restaurantId: restaurantId,
      text: text,
      parentId: parentId,
    );

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
    _bumpCommentCount(restaurantId);
    notifyListeners();
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

    // Covers the cold-start case: already signed in when AppState is
    // constructed, so _onAuthChanged's listener never fires (nothing
    // changed, the app just started). _onAuthChanged covers signing
    // in during a session that started signed out.
    final uid = _authService?.currentUser?.uid;
    if (_useFirebase && uid != null && uid != _reconciledVotesUid) {
      _reconciledVotesUid = uid;
      unawaited(_reconcileVotesFromServer(uid));
    }
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
