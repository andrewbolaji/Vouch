import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';

void main() {
  group('MembershipProvider', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

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
}
