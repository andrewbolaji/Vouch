import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/theme/app_theme.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final membership = context.watch<MembershipProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text('Unlock more', style: AppTheme.displayMedium),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Choose the plan that fits your appetite.',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            // Billing toggle
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Monthly',
                    style: AppTheme.labelMedium.copyWith(
                      color: !membership.isYearlyBilling
                          ? AppTheme.accent
                          : AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Switch(
                    value: membership.isYearlyBilling,
                    onChanged: (_) => membership.toggleBillingCycle(),
                    activeTrackColor: AppTheme.accent,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Yearly',
                    style: AppTheme.labelMedium.copyWith(
                      color: membership.isYearlyBilling
                          ? AppTheme.accent
                          : AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            // Tier cards
            ...membershipTiers.skip(1).map((tier) {
              final isCurrentTier = membership.currentTier == tier.tier;
              final price = membership.isYearlyBilling
                  ? tier.yearlyPrice
                  : tier.monthlyPrice;
              final period = membership.isYearlyBilling ? '/year' : '/month';

              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isCurrentTier ? AppTheme.accent : AppTheme.divider,
                    width: isCurrentTier ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tier.name, style: AppTheme.headlineLarge),
                        ),
                        Text(
                          '$price$period',
                          style: AppTheme.headlineMedium.copyWith(
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    ...tier.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.accent,
                              size: 18,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(feature, style: AppTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isCurrentTier
                            ? null
                            : () async {
                                await membership.purchaseTier(tier.tier);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrentTier
                              ? AppTheme.surfaceVariant
                              : AppTheme.accent,
                          foregroundColor: AppTheme.onAccent,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingMd,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                        ),
                        child: Text(
                          isCurrentTier
                              ? 'Current Plan'
                              : 'Start 7-day free trial',
                          style: AppTheme.buttonText.copyWith(
                            color: isCurrentTier
                                ? AppTheme.textTertiary
                                : AppTheme.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppTheme.spacingSm),
            Center(
              child: TextButton(
                onPressed: membership.restorePurchases,
                child: Text(
                  'Restore purchases',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.accent),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }
}
