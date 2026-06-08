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
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.spacingXs),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
