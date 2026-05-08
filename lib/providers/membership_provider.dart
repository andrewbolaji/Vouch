import 'package:flutter/foundation.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/services/revenue_cat_service.dart';

class MembershipProvider extends ChangeNotifier {
  MembershipProvider({
    MembershipTier initialTier = MembershipTier.free,
  }) : _currentTier = initialTier;

  MembershipTier _currentTier;
  bool _isYearlyBilling = false;

  MembershipTier get currentTier => _currentTier;
  bool get isYearlyBilling => _isYearlyBilling;

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

  Future<void> purchaseTier(MembershipTier tier) async {
    final productId = _productIdFor(tier);
    final success = await RevenueCatService.purchase(productId);
    if (success) {
      _currentTier = tier;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    final entitlements = await RevenueCatService.restorePurchases();
    _currentTier = _tierFromEntitlements(entitlements);
    notifyListeners();
  }

  /// Check entitlements on app launch or after sign-in.
  Future<void> refreshEntitlements() async {
    final entitlements = await RevenueCatService.getActiveEntitlements();
    _currentTier = _tierFromEntitlements(entitlements);
    notifyListeners();
  }

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
}
