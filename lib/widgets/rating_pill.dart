import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class RatingPill extends StatelessWidget {

  const RatingPill({required this.rank, super.key, this.isLarge = false});
  final int rank;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge
            ? AppTheme.spacingMd
            : AppTheme.spacingSm + AppTheme.spacingXxs,
        vertical: isLarge ? AppTheme.spacingSm : AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: isTop ? AppTheme.accent : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.borderColor,
          width: AppTheme.borderInkWidth,
        ),
      ),
      child: Text(
        '#$rank',
        style: AppTheme.rankDisplay.copyWith(
          fontSize: isLarge ? 22 : 18,
          color: isTop ? AppTheme.onAccent : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
