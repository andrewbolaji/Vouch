import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/services/revenue_cat_service.dart';

void main() {
  group('MembershipProvider', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      RevenueCatService.resetSimulatedState();
    });

    test('starts at free tier', () {
      final provider = MembershipProvider();
      expect(
        provider.currentTier,
        MembershipTier.free,
      );
      expect(provider.tierName, 'Free');
    });

    test('free tier has correct permissions', () {
      final provider = MembershipProvider();
      expect(provider.canViewTop10, isFalse);
      expect(provider.canSaveRestaurants, isFalse);
      expect(provider.canViewInsiderTips, isFalse);
      expect(provider.hasInsiderBadge, isFalse);
      expect(provider.isAdFree, isFalse);
    });

    test('localsPass tier permissions', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      expect(provider.canViewTop10, isTrue);
      expect(provider.canSaveRestaurants, isTrue);
      expect(provider.canViewInsiderTips, isFalse);
      expect(provider.hasInsiderBadge, isFalse);
      expect(provider.isAdFree, isTrue);
      expect(provider.tierName, 'Locals Pass');
    });

    test('cityInsider tier permissions', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(
        MembershipTier.cityInsider,
      );

      expect(provider.canViewTop10, isTrue);
      expect(provider.canSaveRestaurants, isTrue);
      expect(provider.canViewInsiderTips, isTrue);
      expect(provider.hasInsiderBadge, isTrue);
      expect(provider.isAdFree, isTrue);
      expect(provider.tierName, 'City Insider');
    });

    test('toggleBillingCycle flips state', () {
      final provider = MembershipProvider();
      expect(provider.isYearlyBilling, isFalse);

      provider.toggleBillingCycle();
      expect(provider.isYearlyBilling, isTrue);

      provider.toggleBillingCycle();
      expect(provider.isYearlyBilling, isFalse);
    });

    test('notifies listeners on purchase', () async {
      final provider = MembershipProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.purchaseTier(MembershipTier.localsPass);
      expect(notified, isTrue);
    });

    test('notifies listeners on billing toggle', () {
      final provider = MembershipProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.toggleBillingCycle();
      expect(notified, isTrue);
    });
  });

  group('MembershipProvider simulate path', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      RevenueCatService.resetSimulatedState();
    });

    test('kSimulatePurchases is true in the test environment', () {
      expect(kSimulatePurchases, isTrue);
    });

    test('simulate purchase localsPass grants locals_pass entitlement',
        () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      // Restore on a fresh provider picks up simulated entitlements
      final provider2 = MembershipProvider();
      await provider2.restorePurchases();
      expect(provider2.currentTier, MembershipTier.localsPass);
    });

    test('simulate purchase cityInsider grants both entitlements', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.cityInsider);

      final provider2 = MembershipProvider();
      await provider2.restorePurchases();
      expect(provider2.currentTier, MembershipTier.cityInsider);
    });

    test('refreshEntitlements reflects simulated state', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.localsPass);

      final provider2 = MembershipProvider();
      await provider2.refreshEntitlements();
      expect(provider2.currentTier, MembershipTier.localsPass);
    });

    test('logOut clears simulated entitlements', () async {
      final provider = MembershipProvider();
      await provider.purchaseTier(MembershipTier.cityInsider);

      await RevenueCatService.logOut();

      final provider2 = MembershipProvider();
      await provider2.refreshEntitlements();
      expect(provider2.currentTier, MembershipTier.free);
    });
  });
}
