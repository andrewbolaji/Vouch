import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class RatingPill extends StatelessWidget {

  const RatingPill({required this.rank, super.key, this.isLarge = false});
  final int rank;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;
    final isFirst = rank == 1;
    // Rank 1 gets a slightly larger chip to crown the spot
    final fontSize = isLarge
        ? (isFirst ? 26.0 : 22.0)
        : (isFirst ? 20.0 : 18.0);
    final hPad = isLarge
        ? AppTheme.spacingMd
        : (isFirst
            ? AppTheme.spacingMdSm
            : AppTheme.spacingSm + AppTheme.spacingXxs);
    final vPad = isLarge
        ? (isFirst ? AppTheme.spacingSm + AppTheme.spacingXxs : AppTheme.spacingSm)
        : (isFirst ? AppTheme.spacingXsSm : AppTheme.spacingXs);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
          fontSize: fontSize,
          color: isTop ? AppTheme.onAccent : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
