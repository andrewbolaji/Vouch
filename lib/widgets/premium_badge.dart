import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class PremiumBadge extends StatelessWidget {

  const PremiumBadge({super.key, this.label = 'PRO'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXsSm,
        vertical: AppTheme.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.goldInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.goldInk.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.goldInk,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
