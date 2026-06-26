import 'package:flutter/material.dart';
import 'package:vouch/core/utils/format_utils.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/rating_pill.dart';
import 'package:vouch/widgets/restaurant_image.dart';

class RestaurantCard extends StatelessWidget {

  const RestaurantCard({
    required this.restaurant, required this.onTap, super.key,
  });
  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showRank = !restaurant.isUnranked;
    final showVotes = restaurant.voteCount > 0;
    // Pinned rule: only rank 1 gets the hard shadow
    final isPrimary = restaurant.rank == 1;
    return Semantics(
      button: true,
      label: '${showRank ? '#${restaurant.rank} ' : ''}'
          '${restaurant.name}, ${restaurant.cuisine}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: isPrimary
            ? AppTheme.cardDecorationPrimary
            : AppTheme.cardDecoration,
        child: Row(
          children: [
            // Image with ink frame
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusSm),
                bottomLeft: Radius.circular(AppTheme.radiusSm),
              ),
              child: RestaurantImage(
                restaurant: restaurant,
                width: 100,
                height: 100,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showRank) ...[
                          RatingPill(rank: restaurant.rank),
                          const SizedBox(width: AppTheme.spacingSm),
                        ],
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: AppTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      '${restaurant.cuisine}  ${restaurant.priceLevelDisplay}',
                      style: AppTheme.bodySmall,
                    ),
                    if (showVotes || isPrimary) ...[
                      const SizedBox(height: AppTheme.spacingXs),
                      Row(
                        children: [
                          if (showVotes)
                            Text(
                              '${formatCount(restaurant.voteCount)} votes',
                              style: AppTheme.voteStat.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          if (isPrimary) ...[
                            if (showVotes)
                              const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'Most vouched',
                              style: AppTheme.voteStat.copyWith(
                                color: AppTheme.goldInk,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingMd),
              child: isPrimary
                  ? Icon(
                      Icons.workspace_premium,
                      color: AppTheme.goldInk,
                      size: 24,
                    )
                  : Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
