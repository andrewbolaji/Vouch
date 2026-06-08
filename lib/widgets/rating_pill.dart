import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class RatingPill extends StatelessWidget {

  const RatingPill({required this.rank, super.key, this.isLarge = false});
  final int rank;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge
            ? AppTheme.spacingMd
            : AppTheme.spacingSm + AppTheme.spacingXxs,
        vertical: isLarge ? AppTheme.spacingSm : AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: rank <= 3 ? AppTheme.accent : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        '#$rank',
        style: (isLarge ? AppTheme.rankDisplay : AppTheme.rankDisplay)
            .copyWith(
              fontSize: isLarge ? 20 : 14,
              color: rank <= 3
                  ? AppTheme.onAccent
                  : AppTheme.textPrimary,
            ),
      ),
    );
  }
}
