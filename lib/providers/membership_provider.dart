import 'package:flutter/foundation.dart';
import 'package:vouch/models/models.dart';
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
  })  : _currentTier = initialTier,
        _authService = authService {
    _authService?.addListener(_onAuthChanged);
  }

  final AuthService? _authService;
  MembershipTier _currentTier;
  bool _isYearlyBilling = false;

  void _onAuthChanged() {
    if (_authService?.isSignedIn == false &&
        _currentTier != MembershipTier.free) {
      _currentTier = MembershipTier.free;
      notifyListeners();
    }
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

  bool get isAdFree =>
      _currentTier == MembershipTier.localsPass ||
      _currentTier == MembershipTier.cityInsider;

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
    if (result == PurchaseResult.success) {
      // In release builds, poll for the custom claim set by the
      // RevenueCat webhook before unlocking gated content.
      if (!kSimulatePurchases && _authService != null) {
        await _pollForMembershipClaim(tier);
      }
      _currentTier = tier;
      notifyListeners();
    }
    return result;
  }

  Future<void> restorePurchases() async {
    final entitlements = await RevenueCatService.restorePurchases();
    final tier = _tierFromEntitlements(entitlements);
    // Force a single token refresh so Firestore rules see the claim.
    if (!kSimulatePurchases && _authService != null) {
      await _authService.forceTokenRefresh();
    }
    _currentTier = tier;
    notifyListeners();
  }

  /// Check entitlements on app launch or after sign-in.
  Future<void> refreshEntitlements() async {
    final entitlements = await RevenueCatService.getActiveEntitlements();
    final tier = _tierFromEntitlements(entitlements);
    if (!kSimulatePurchases && _authService != null && tier != _currentTier) {
      await _authService.forceTokenRefresh();
    }
    _currentTier = tier;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Claim polling
  // ------------------------------------------------------------------

  /// Force-refreshes the ID token up to [kClaimPollMaxRetries] times,
  /// checking whether the membershipTier custom claim matches
  /// [expectedTier]. Backs off by [kClaimPollDelay] between retries.
  Future<void> _pollForMembershipClaim(MembershipTier expectedTier) async {
    final expectedClaim = _tierToClaimString(expectedTier);

    for (var i = 0; i < kClaimPollMaxRetries; i++) {
      final claim = await _authService!.getMembershipTierClaim();
      if (claim == expectedClaim) return;
      if (i < kClaimPollMaxRetries - 1) {
        await Future<void>.delayed(kClaimPollDelay);
      }
    }
    debugPrint(
      'MembershipProvider: claim poll exhausted after '
      '$kClaimPollMaxRetries retries, proceeding',
    );
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
