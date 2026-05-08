enum MembershipTier { free, localsPass, cityInsider }

class MembershipInfo {

  const MembershipInfo({
    required this.tier,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
  });
  final MembershipTier tier;
  final String name;
  final String monthlyPrice;
  final String yearlyPrice;
  final List<String> features;
}

class InsiderNote {

  const InsiderNote({
    required this.restaurantId,
    required this.whatToOrder,
    required this.tip,
  });
  final String restaurantId;
  final String whatToOrder;
  final String tip;
}

const List<MembershipInfo> membershipTiers = [
  MembershipInfo(
    tier: MembershipTier.free,
    name: 'Free',
    monthlyPrice: r'$0',
    yearlyPrice: r'$0',
    features: ['Top 5 rankings', 'Vote and comment'],
  ),
  MembershipInfo(
    tier: MembershipTier.localsPass,
    name: 'Locals Pass',
    monthlyPrice: r'$4.99',
    yearlyPrice: r'$39.99',
    features: [
      'Top 10 rankings',
      'Vote and comment',
      'Save restaurants',
      'Trending tab',
      'Ad-free',
    ],
  ),
  MembershipInfo(
    tier: MembershipTier.cityInsider,
    name: 'City Insider',
    monthlyPrice: r'$9.99',
    yearlyPrice: r'$79.99',
    features: [
      'Everything in Locals Pass',
      'Insider "what to order" tips',
      'Insider badge on comments',
      'Verified visits (2x vote weight)',
      'Early access to new cities',
    ],
  ),
];
