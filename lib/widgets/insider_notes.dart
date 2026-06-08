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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryMuted, AppTheme.surfaceVariant],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                'Insider Notes',
                style: AppTheme.accentItalic,
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
