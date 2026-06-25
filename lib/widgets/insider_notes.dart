import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';

class InsiderNotes extends StatelessWidget {

  const InsiderNotes({super.key, this.whatToOrder, this.tip});
  final String? whatToOrder;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    if (whatToOrder == null && tip == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.goldInk.withValues(alpha: 0.4),
          width: AppTheme.borderInkWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.goldInk,
                size: 18,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                'Insider Notes',
                style: AppTheme.accentItalic.copyWith(
                  color: AppTheme.goldInk,
                ),
              ),
            ],
          ),
          if (whatToOrder != null) ...[
            const SizedBox(height: AppTheme.spacingMd),
            Text('What to order', style: AppTheme.labelMedium),
            const SizedBox(height: AppTheme.spacingXs),
            Text(whatToOrder!, style: AppTheme.bodyMedium),
          ],
          if (tip != null) ...[
            const SizedBox(height: AppTheme.spacingMd),
            Text('Pro tip', style: AppTheme.labelMedium),
            const SizedBox(height: AppTheme.spacingXs),
            Text(tip!, style: AppTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
