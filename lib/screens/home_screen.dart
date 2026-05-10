import 'package:cached_network_image/cached_network_image.dart';
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
                            fillColor: AppTheme.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingMd,
                            ),
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
                const SizedBox(height: 2),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppTheme.surfaceVariant),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: AppTheme.surfaceVariant,
                    child: Icon(
                      Icons.location_city,
                      color: AppTheme.textTertiary,
                      size: 40,
                    ),
                  ),
                ),
              ),
              Container(
                color: AppTheme.cardBackground,
                padding: const EdgeInsets.all(AppTheme.spacingSm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name, $state',
                      style: AppTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
