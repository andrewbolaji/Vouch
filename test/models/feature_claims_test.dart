import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/membership.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/services/revenue_cat_service.dart';

/// Marks a feature bullet as deliberately not gated behind any
/// [MembershipProvider] capability, either because every tier gets it
/// for free (`Top 5 rankings`, `Vote and comment`) or because the
/// bullet is a summary of a lower tier's features rather than a claim
/// of its own (`Everything in Locals Pass`). Present so the absence of
/// a capability check reads as a decision, not an oversight.
bool ungated(MembershipProvider _) => true;

/// Every paywall bullet across every tier, mapped to the capability
/// that actually backs it. The value is a closure, not a string
/// naming a getter, so a typo or a deleted getter fails to compile
/// instead of failing silently at runtime.
final claims = <String, bool Function(MembershipProvider)>{
  'Top 5 rankings': ungated,
  'Vote and comment': ungated,
  'Top 10 rankings': (p) => p.canViewTop10,
  'Save restaurants': (p) => p.canSaveRestaurants,
  'Everything in Locals Pass': ungated,
  'Insider "what to order" tips': (p) => p.canViewInsiderTips,
  'Insider badge on comments': (p) => p.hasInsiderBadge,
};

void main() {
  test('every feature bullet in every tier has a claims entry', () {
    for (final tier in membershipTiers) {
      for (final feature in tier.features) {
        expect(
          claims.containsKey(feature),
          isTrue,
          reason:
              'MembershipInfo lists "$feature" under ${tier.name} '
              'but there is no matching entry in the claims map in '
              'feature_claims_test.dart. Add a capability closure, or '
              '`ungated` if it is deliberately not gated.',
        );
      }
    }
  });

  test('simulated store prices match the membership copy', () async {
    final prices = await RevenueCatService.getLocalizedPrices();

    for (final tier in membershipTiers.where(
      (tier) => tier.tier != MembershipTier.free,
    )) {
      expect(
        prices[RevenueCatConfig.productIdFor(tier.tier, yearly: false)],
        tier.monthlyPrice,
        reason:
            '${tier.name} monthly price drifted between the paywall '
            'model and RevenueCat simulation.',
      );
      expect(
        prices[RevenueCatConfig.productIdFor(tier.tier, yearly: true)],
        tier.yearlyPrice,
        reason:
            '${tier.name} yearly price drifted between the paywall '
            'model and RevenueCat simulation.',
      );
    }
  });
}
