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
    final showComments = restaurant.commentCount > 0;
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
              borderRadius: const BorderRadius.only(
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
                    // The vote count always renders, including at
                    // zero, so this row is unconditional. Comment
                    // count still hides at zero and the asymmetry is
                    // deliberate.
                    //
                    // A list where some cards carry a number and
                    // others carry nothing reads as broken rather
                    // than as empty. At launch every count is zero,
                    // so hiding them meant the app displayed no vote
                    // count anywhere, and a voting app whose first
                    // screen shows no evidence that voting exists is
                    // not communicating its own premise.
                    //
                    // It also pairs with Fix B's opening-list line.
                    // "Ranked by locals as votes come in" beside a
                    // column of zeroes tells the user what they are
                    // looking at and what their tap would do. Hidden
                    // zeroes leave that sentence doing the work
                    // alone.
                    //
                    // Comments are different: a zero there says
                    // nothing has been said, which is not a call to
                    // action and not part of the ranking premise.
                    const SizedBox(height: AppTheme.spacingXs),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingXxs,
                      children: [
                        Text(
                          '${formatCount(restaurant.voteCount)} votes',
                          style: AppTheme.voteStat.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (showComments)
                          Semantics(
                            label: '${restaurant.commentCount} comments',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppTheme.textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  formatCount(restaurant.commentCount),
                                  style: AppTheme.voteStat.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isPrimary)
                          Text(
                            'Most vouched',
                            style: AppTheme.voteStat.copyWith(
                              color: AppTheme.goldInk,
                            ),
                          ),
                      ],
                    ),
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
