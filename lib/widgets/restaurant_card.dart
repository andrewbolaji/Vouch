import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vouch/core/utils/format_utils.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/rating_pill.dart';

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
    return Semantics(
      button: true,
      label: '${showRank ? '#${restaurant.rank} ' : ''}'
          '${restaurant.name}, ${restaurant.cuisine}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMd),
                bottomLeft: Radius.circular(AppTheme.radiusMd),
              ),
              child: CachedNetworkImage(
                imageUrl: restaurant.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 100,
                  height: 100,
                  color: AppTheme.surfaceVariant,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 100,
                  height: 100,
                  color: AppTheme.surfaceVariant,
                  child: Icon(Icons.restaurant, color: AppTheme.textTertiary),
                ),
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
                    if (showVotes) ...[
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        '${formatCount(restaurant.voteCount)} votes',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingMd),
              child: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
