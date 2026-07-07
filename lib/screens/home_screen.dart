import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/config/brand_config.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/city_detail_screen.dart';
import 'package:vouch/screens/profile_screen.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/premium_badge.dart';
import 'package:vouch/widgets/shimmer_loading.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final membership = context.watch<MembershipProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: appState.isLoading
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HomeHeader(membership: membership),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTheme.spacingLg),
                  ),
                  const SliverToBoxAdapter(child: CityGridShimmer()),
                ],
              )
            : RefreshIndicator(
                color: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                onRefresh: appState.refresh,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HomeHeader(membership: membership),
                    ),
                    // Search bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                        ),
                        child: TextField(
                          onChanged: appState.setSearchQuery,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search cities...',
                            hintStyle: AppTheme.bodyMedium,
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.textTertiary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              borderSide: BorderSide(
                                color: AppTheme.borderColor,
                                width: AppTheme.borderInkWidth,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              borderSide: BorderSide(
                                color: AppTheme.borderColor,
                                width: AppTheme.borderInkWidth,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              borderSide: BorderSide(
                                color: AppTheme.accent,
                                width: AppTheme.borderInkWidth,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingMd,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Offline indicator
                    if (appState.isOffline)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                          ).copyWith(top: AppTheme.spacingSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                              vertical: AppTheme.spacingSm,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              border: Border.all(
                                color: AppTheme.textTertiary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  color: AppTheme.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                Expanded(
                                  child: Text(
                                    "Can't reach the network right now. "
                                    'Some info may be missing.',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppTheme.spacingLg),
                    ),
                    // Empty search state
                    if (appState.cities.isEmpty &&
                        appState.searchQuery != null &&
                        appState.searchQuery!.isNotEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.explore_outlined,
                                color: AppTheme.textTertiary,
                                size: 48,
                              ),
                              const SizedBox(height: AppTheme.spacingMd),
                              Text(
                                "We're not there yet",
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXs),
                              Text(
                                'Tap your profile to suggest a city.'
                                ' We add new ones based on'
                                ' what locals ask for.',
                                style: AppTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // City grid
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppTheme.spacingMd,
                                crossAxisSpacing: AppTheme.spacingMd,
                                childAspectRatio: 0.85,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final city = appState.cities[index];
                            if (!city.isLive) {
                              return _ComingSoonCityCard(
                                name: city.name,
                                state: city.state,
                              );
                            }
                            return _CityCard(
                              name: city.name,
                              state: city.state,
                              imageUrl: city.imageUrl,
                              description: city.description,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CityDetailScreen(cityId: city.id),
                                ),
                              ),
                            );
                          }, childCount: appState.cities.length),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppTheme.spacingXl),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {

  const _HomeHeader({required this.membership});
  final MembershipProvider membership;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(BrandConfig.appName, style: AppTheme.displayMedium),
                const SizedBox(height: AppTheme.spacingXxs),
                Text.rich(
                  TextSpan(
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    children: [
                      const TextSpan(text: 'Where locals '),
                      TextSpan(
                        text: 'actually',
                        style: TextStyle(color: AppTheme.accent),
                      ),
                      const TextSpan(text: ' eat'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (membership.currentTier != MembershipTier.free)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingSm),
              child: PremiumBadge(label: membership.tierName),
            ),
          Semantics(
            button: true,
            label: 'Open profile',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileScreen(),
                ),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.surfaceVariant,
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityCard extends StatelessWidget {

  const _CityCard({
    required this.name,
    required this.state,
    required this.imageUrl,
    required this.description,
    required this.onTap,
  });
  final String name;
  final String state;
  final String imageUrl;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name, $state',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: AppTheme.cardDecoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // State abbreviation watermark
              Positioned(
                right: -AppTheme.spacingSm,
                bottom: -AppTheme.spacingSm,
                child: Text(
                  state,
                  style: AppTheme.displayLarge.copyWith(
                    fontSize: AppTheme.watermarkFontSize,
                    color: AppTheme.textPrimary.withValues(
                      alpha: AppTheme.alphaWatermark,
                    ),
                  ),
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXxs),
                    Text(
                      state,
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Top 10 pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm,
                        vertical: AppTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.accent,
                          width: AppTheme.borderInkWidth,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: AppTheme.spacingXsSm,
                            height: AppTheme.spacingXsSm,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingXs),
                          Text(
                            'Top 10',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonCityCard extends StatelessWidget {
  const _ComingSoonCityCard({
    required this.name,
    required this.state,
  });
  final String name;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name, $state, coming soon',
      child: Opacity(
        opacity: 0.55,
        child: Container(
          decoration: AppTheme.cardDecoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -AppTheme.spacingSm,
                bottom: -AppTheme.spacingSm,
                child: Text(
                  state,
                  style: AppTheme.displayLarge.copyWith(
                    fontSize: AppTheme.watermarkFontSize,
                    color: AppTheme.textPrimary.withValues(
                      alpha: AppTheme.alphaWatermark,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXxs),
                    Text(
                      state,
                      style: AppTheme.bodySmall,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm,
                        vertical: AppTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.textTertiary,
                          width: AppTheme.borderInkWidth,
                        ),
                      ),
                      child: Text(
                        'Coming soon',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
