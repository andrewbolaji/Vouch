import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vouch/theme/app_theme.dart';

/// Shimmer placeholder for the city grid on HomeScreen.
class CityGridShimmer extends StatelessWidget {
  const CityGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.surface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacingMd,
          crossAxisSpacing: AppTheme.spacingMd,
          childAspectRatio: 0.85,
        ),
        itemCount: 4,
        itemBuilder: (context, index) => const _ShimmerCityCard(),
      ),
    );
  }
}

class _ShimmerCityCard extends StatelessWidget {
  const _ShimmerCityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              AppTheme.spacingSm + AppTheme.spacingXxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                  ),
                ),
                const SizedBox(
                  height: AppTheme.spacingXsSm,
                ),
                Container(
                  width: 140,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for restaurant list items on CityDetailScreen.
class RestaurantListShimmer extends StatelessWidget {

  const RestaurantListShimmer({super.key, this.itemCount = 5});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.surface,
      child: Column(
        children: List.generate(itemCount, (index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: _ShimmerRestaurantCard(),
          );
        }),
      ),
    );
  }
}

class _ShimmerRestaurantCard extends StatelessWidget {
  const _ShimmerRestaurantCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    width: 100,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
