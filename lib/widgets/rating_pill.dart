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
        horizontal: isLarge ? AppTheme.spacingMd : AppTheme.spacingSm + 2,
        vertical: isLarge ? AppTheme.spacingSm : 4,
      ),
      decoration: BoxDecoration(
        color: rank <= 3 ? AppTheme.accent : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        '#$rank',
        style: (isLarge ? AppTheme.headlineMedium : AppTheme.labelLarge)
            .copyWith(
              color: rank <= 3
                  ? (AppTheme.brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white)
                  : AppTheme.textPrimary,
            ),
      ),
    );
  }
}
