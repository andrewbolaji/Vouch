import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/services/analytics_service.dart';
import 'package:vouch/services/revenue_cat_service.dart';
import 'package:vouch/theme/app_theme.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({
    super.key,
    @visibleForTesting this.priceLoader,
  });

  final Future<Map<String, String>> Function()? priceLoader;

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Map<String, String>? _prices;
  bool _loading = true;
  bool _priceError = false;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    setState(() {
      _loading = true;
      _priceError = false;
    });

    try {
      final loader =
          widget.priceLoader ?? RevenueCatService.getLocalizedPrices;
      final prices = await loader();
      if (!mounted) return;

      if (prices.isEmpty) {
        setState(() {
          _priceError = true;
          _loading = false;
        });
        return;
      }

      setState(() {
        _prices = prices;
        _loading = false;
      });
    } on Exception catch (e, stack) {
      if (!mounted) return;
      _recordError('getLocalizedPrices', e, stack);
      setState(() {
        _priceError = true;
        _loading = false;
      });
    }
  }

  static void _recordError(String reason, Object error, StackTrace stack) {
    try {
      unawaited(FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'UpgradeScreen: $reason',
      ));
    } on Exception catch (_) {
      // Crashlytics unavailable (unit tests without Firebase).
    }
  }

  String? _priceFor(MembershipTier tier, {required bool yearly}) {
    if (_prices == null || _prices!.isEmpty) return null;
    final productId = RevenueCatConfig.productIdFor(tier, yearly: yearly);
    return _prices![productId];
  }

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
          top: Radius.circular(AppTheme.spacingMd),
        ),
        border: Border(
          top: AppTheme.borderInk,
          left: AppTheme.borderInk,
          right: AppTheme.borderInk,
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
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
                  Semantics(
                    toggled: membership.isYearlyBilling,
                    label: 'Yearly billing',
                    child: Switch(
                      value: membership.isYearlyBilling,
                      onChanged: (_) => membership.toggleBillingCycle(),
                      activeTrackColor: AppTheme.accent,
                    ),
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
            if (_priceError) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: AppTheme.borderInkWidth,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Could not load prices. Check your '
                      'connection and try again.',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextButton(
                      onPressed: _loadPrices,
                      child: Text(
                        'Retry',
                        style: AppTheme.buttonText.copyWith(
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
            // Tier cards
            ...membershipTiers.skip(1).map((tier) {
              final isCurrentTier = membership.currentTier == tier.tier;
              final price = _priceFor(
                tier.tier,
                yearly: membership.isYearlyBilling,
              );
              final period = membership.isYearlyBilling ? '/year' : '/month';

              return Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isCurrentTier
                        ? AppTheme.goldInk
                        : AppTheme.borderColor,
                    width: AppTheme.borderInkWidth,
                  ),
                  boxShadow: isCurrentTier ? AppTheme.shadowHard : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tier.name, style: AppTheme.headlineLarge),
                        ),
                        if (_loading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.goldInk,
                            ),
                          )
                        else if (price != null)
                          Text(
                            '$price$period',
                            style: AppTheme.headlineMedium.copyWith(
                              color: AppTheme.goldInk,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    ...tier.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacingXsSm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.goldInk,
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
                        onPressed: isCurrentTier || _loading || _purchasing
                            ? null
                            : () => _handlePurchase(context, tier.tier),
                        style: isCurrentTier
                            ? AppTheme.secondaryButtonStyle
                            : AppTheme.accentButtonStyle,
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
          if (_purchasing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.spacingMd),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.accent,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'Confirming your purchase...',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    MembershipTier tier,
  ) async {
    context.read<AnalyticsService>().logUpgradeTap(tier: tier.name);
    final membership = context.read<MembershipProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _purchasing = true);
    final result = await membership.purchaseTier(tier);

    if (!mounted) return;

    setState(() => _purchasing = false);

    switch (result) {
      case PurchaseResult.success:
        navigator.pop();
      case PurchaseResult.cancelled:
        break; // User cancelled, no error needed.
      case PurchaseResult.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
