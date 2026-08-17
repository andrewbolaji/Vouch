import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/repositories/membership_repository.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/services/revenue_cat_service.dart';

/// Maximum number of token-refresh attempts after a purchase while
/// waiting for the webhook to set the membershipTier custom claim.
const int kClaimPollMaxRetries = 5;

/// Delay between each claim-poll retry.
const Duration kClaimPollDelay = Duration(seconds: 2);

class MembershipProvider extends ChangeNotifier {
  MembershipProvider({
    MembershipTier initialTier = MembershipTier.free,
    AuthService? authService,
    bool? simulatePurchases,
    MembershipRepository? membershipRepo,
  }) : _currentTier = initialTier,
       _authService = authService,
       _membershipRepo = membershipRepo,
       _simulatePurchases = simulatePurchases ?? kSimulatePurchases {
    _authService?.addListener(_onAuthChanged);
  }

  final AuthService? _authService;

  /// Server-side reconciliation against RevenueCat.
  ///
  /// Injectable but not required, and constructed on demand when it
  /// is absent rather than defaulting to doing nothing. That is
  /// deliberate: a nullable dependency whose null branch silently
  /// skips the feature is exactly how VoteRepository shipped unwired
  /// for months, with every test still passing. Here a missing
  /// repository cannot disable reconciliation, it can only fail to
  /// substitute for it.
  ///
  /// Constructed lazily rather than in the constructor because
  /// MembershipRepository reaches FirebaseAuth.instance, which throws
  /// in a widget test with no Firebase. The lazy path is only ever
  /// reached in a non-simulate build, which no test runs by default.
  final MembershipRepository? _membershipRepo;

  /// Mirrors AppState's useFirebase seam. kSimulatePurchases is a
  /// compile-time const tied to kDebugMode, so without an override
  /// the claim-confirmation path is unreachable from any test: tests
  /// run in debug, and debug always simulates. Production passes
  /// nothing and gets kSimulatePurchases.
  final bool _simulatePurchases;
  MembershipTier _currentTier;
  bool _isYearlyBilling = false;

  /// True when RevenueCat reports an active entitlement that the
  /// Firebase custom claim has not caught up to yet.
  ///
  /// Deliberately a plain in-memory field with no persistence
  /// anywhere, and recomputed from live state by every path that can
  /// set it. Storing it would strand a user who backgrounds the app
  /// mid-purchase: they would return to a confirming state that
  /// nothing re-evaluates, with no way out. Dying with the process
  /// and being rederived on launch is the whole point.
  ///
  /// While this is true the tier stays free and gated content stays
  /// locked. That is not pessimism, it is accuracy: firestore.rules
  /// gates on the claim, so unlocking the UI before the claim lands
  /// would produce denied reads and a broken screen rather than
  /// early access.
  bool _isAwaitingConfirmation = false;

  bool get isAwaitingConfirmation => _isAwaitingConfirmation;

  void _onAuthChanged() {
    if (_authService?.isSignedIn == false) {
      if (_currentTier != MembershipTier.free || _isAwaitingConfirmation) {
        _currentTier = MembershipTier.free;
        _isAwaitingConfirmation = false;
        notifyListeners();
      }
      return;
    }
    // Signed in: re-derive against this account's own entitlements
    // and claim. Covers sign-in during a session; launch is covered
    // by main.dart calling refreshEntitlements directly.
    unawaited(refreshEntitlements());
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  MembershipTier get currentTier => _currentTier;
  bool get isYearlyBilling => _isYearlyBilling;

  /// Test only: sets the tier and notifies listeners.
  @visibleForTesting
  void setTierForTest(MembershipTier tier) {
    _currentTier = tier;
    notifyListeners();
  }

  bool get canViewTop10 =>
      _currentTier == MembershipTier.localsPass ||
      _currentTier == MembershipTier.cityInsider;

  bool get canSaveRestaurants =>
      _currentTier == MembershipTier.localsPass ||
      _currentTier == MembershipTier.cityInsider;

  bool get canViewInsiderTips => _currentTier == MembershipTier.cityInsider;

  bool get hasInsiderBadge => _currentTier == MembershipTier.cityInsider;

  String get tierName {
    switch (_currentTier) {
      case MembershipTier.free:
        return 'Free';
      case MembershipTier.localsPass:
        return 'Locals Pass';
      case MembershipTier.cityInsider:
        return 'City Insider';
    }
  }

  void toggleBillingCycle() {
    _isYearlyBilling = !_isYearlyBilling;
    notifyListeners();
  }

  Future<PurchaseResult> purchaseTier(MembershipTier tier) async {
    final productId = _productIdFor(tier);
    final result = await RevenueCatService.purchase(productId);
    if (result != PurchaseResult.success) return result;

    if (_simulatePurchases || _authService == null) {
      _currentTier = tier;
      _isAwaitingConfirmation = false;
      notifyListeners();
      return result;
    }

    // Poll for the custom claim the RevenueCat webhook sets. Only a
    // confirmed claim unlocks anything: this used to set the tier
    // regardless of the poll's outcome, which rendered an
    // unconfirmed purchase as paid and produced a UI whose gated
    // reads firestore.rules then denied.
    final confirmed = await _pollForMembershipClaim(tier);
    if (confirmed) {
      _currentTier = tier;
      _isAwaitingConfirmation = false;
    } else {
      _currentTier = MembershipTier.free;
      _isAwaitingConfirmation = true;
    }
    notifyListeners();
    return result;
  }

  /// Re-checks a purchase that RevenueCat confirms and the claim does
  /// not. Backs the retry affordance on the pending UI, so a user who
  /// has paid has something to do other than wait.
  ///
  /// Asks the server to reconcile first, then re-derives. Before
  /// reconciliation existed this method could only re-read a claim
  /// that nothing was going to change: the webhook is the only writer
  /// of that claim, and the case being retried is precisely the case
  /// where the webhook never arrived. A retry button that cannot
  /// affect its own outcome is worse than no button, because it makes
  /// the user believe the problem is theirs to solve by waiting.
  ///
  /// A reconciliation failure is swallowed rather than surfaced. The
  /// refresh below still runs, so the outcome is the state the user
  /// was already in, which is what the pending screen already
  /// describes. There is nothing more useful to say to somebody whose
  /// purchase is still not visible than what it already says.
  Future<void> retryConfirmation() async {
    if (!_isAwaitingConfirmation) return;
    if (!_simulatePurchases) {
      try {
        await (_membershipRepo ?? MembershipRepository()).reconcile();
        // The claim may have just changed server-side, and the cached
        // ID token predates it. refreshEntitlements force-refreshes
        // the token itself, which is what makes the new claim visible
        // to the check below rather than one launch later.
      } on Exception catch (e) {
        debugPrint('MembershipProvider: reconcile failed: $e');
      }
    }
    await refreshEntitlements();
  }

  Future<void> restorePurchases() async {
    final entitlements = await RevenueCatService.restorePurchases();
    await _applyEntitlements(entitlements);
  }

  /// Recomputes tier and pending state from live entitlements and the
  /// live custom claim. Called on launch and on sign-in.
  ///
  /// This is the only thing that clears a pending state, which is why
  /// it must run on every launch: a purchase whose claim landed while
  /// the app was closed resolves here, rather than the app coming
  /// back up still confirming.
  Future<void> refreshEntitlements() async {
    final entitlements = await RevenueCatService.getActiveEntitlements();
    await _applyEntitlements(entitlements);
  }

  /// Applies RevenueCat's answer only when it agrees with the custom
  /// claim Firestore rules enforce. Restore and launch refresh must share
  /// this gate: treating a restored entitlement as paid before its claim
  /// exists unlocks a UI whose first gated read is then denied by the rules.
  Future<void> _applyEntitlements(Set<String> entitlements) async {
    final entitledTier = _tierFromEntitlements(entitlements);

    // No entitlement at all: nothing to confirm, nothing pending.
    if (entitledTier == MembershipTier.free) {
      _currentTier = MembershipTier.free;
      _isAwaitingConfirmation = false;
      notifyListeners();
      return;
    }

    // Debug builds simulate purchases and have no real claim to wait
    // on, so there is nothing that could be pending.
    if (_simulatePurchases || _authService == null) {
      _currentTier = entitledTier;
      _isAwaitingConfirmation = false;
      notifyListeners();
      return;
    }

    await _authService.forceTokenRefresh();
    final claimedTier = _tierFromClaim(
      await _authService.getMembershipTierClaim(),
    );

    if (claimedTier == entitledTier) {
      _currentTier = entitledTier;
      _isAwaitingConfirmation = false;
    } else {
      // Paid according to RevenueCat, not yet according to the claim
      // firestore.rules actually enforces. Locked and pending.
      _currentTier = MembershipTier.free;
      _isAwaitingConfirmation = true;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Claim polling
  // ------------------------------------------------------------------

  /// Force-refreshes the ID token up to [kClaimPollMaxRetries] times,
  /// checking whether the membershipTier custom claim matches
  /// [expectedTier]. Backs off by [kClaimPollDelay] between retries.
  /// Returns true once the claim matches [expectedTier], false if it
  /// never did within the retry budget. The caller decides what an
  /// unconfirmed purchase means; this only reports.
  Future<bool> _pollForMembershipClaim(MembershipTier expectedTier) async {
    final expectedClaim = _tierToClaimString(expectedTier);

    for (var i = 0; i < kClaimPollMaxRetries; i++) {
      final claim = await _authService!.getMembershipTierClaim();
      if (claim == expectedClaim) return true;
      if (i < kClaimPollMaxRetries - 1) {
        await Future<void>.delayed(kClaimPollDelay);
      }
    }
    debugPrint(
      'MembershipProvider: claim poll exhausted after '
      '$kClaimPollMaxRetries retries, proceeding',
    );
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          Exception('claim poll exhausted after $kClaimPollMaxRetries retries'),
          StackTrace.current,
          reason:
              'MembershipProvider: _pollForMembershipClaim '
              '(expected=$expectedClaim)',
        ),
      );
    } on Exception catch (_) {
      // Crashlytics unavailable (unit tests).
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  String _productIdFor(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.free:
        return '';
      case MembershipTier.localsPass:
        return _isYearlyBilling
            ? RevenueCatConfig.localsPassYearly
            : RevenueCatConfig.localsPassMonthly;
      case MembershipTier.cityInsider:
        return _isYearlyBilling
            ? RevenueCatConfig.cityInsiderYearly
            : RevenueCatConfig.cityInsiderMonthly;
    }
  }

  MembershipTier _tierFromEntitlements(Set<String> entitlements) {
    if (entitlements.contains(RevenueCatConfig.cityInsiderEntitlement)) {
      return MembershipTier.cityInsider;
    }
    if (entitlements.contains(RevenueCatConfig.localsPassEntitlement)) {
      return MembershipTier.localsPass;
    }
    return MembershipTier.free;
  }

  /// Inverse of [_tierToClaimString]. An absent or unrecognised claim
  /// is free, which is what firestore.rules treats it as.
  static MembershipTier _tierFromClaim(String? claim) {
    switch (claim) {
      case 'cityInsider':
        return MembershipTier.cityInsider;
      case 'localsPass':
        return MembershipTier.localsPass;
      default:
        return MembershipTier.free;
    }
  }

  static String _tierToClaimString(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.free:
        return 'free';
      case MembershipTier.localsPass:
        return 'localsPass';
      case MembershipTier.cityInsider:
        return 'cityInsider';
    }
  }
}
