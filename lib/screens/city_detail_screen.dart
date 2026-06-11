import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/providers/app_state.dart';
import 'package:vouch/providers/membership_provider.dart';
import 'package:vouch/screens/restaurant_detail_screen.dart';
import 'package:vouch/screens/upgrade_screen.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/paywall_gate.dart';
import 'package:vouch/widgets/restaurant_card.dart';

class CityDetailScreen extends StatefulWidget {

  const CityDetailScreen({required this.cityId, super.key});
  final String cityId;

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen> {
  bool _showTop10 = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final membership = context.watch<MembershipProvider>();
    final city = appState.cityById(widget.cityId);
    if (city == null) return const SizedBox.shrink();

    final allRestaurants = appState.restaurantsForCity(widget.cityId);
    final top5 = allRestaurants.where((r) => r.rank <= 5).toList();
    final top6to10 = allRestaurants.where((r) => r.rank > 5).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: appState.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city.displayName, style: AppTheme.displayLarge),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                city.description,
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Toggle
              Row(
                children: [
                  _ToggleButton(
                    label: 'Top 5',
                    isActive: !_showTop10,
                    onTap: () => setState(() => _showTop10 = false),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _ToggleButton(
                    label: 'Top 10',
                    isActive: _showTop10,
                    onTap: () => setState(() => _showTop10 = true),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Restaurant list
              ...top5.map(
                (r) => RestaurantCard(
                  restaurant: r,
                  onTap: () => _openRestaurant(r),
                ),
              ),
              if (_showTop10 && top6to10.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSm),
                if (membership.canViewTop10)
                  ...top6to10.map(
                    (r) => RestaurantCard(
                      restaurant: r,
                      onTap: () => _openRestaurant(r),
                    ),
                  )
                else
                  PaywallGate(
                    isLocked: true,
                    onUpgradeTap: () {
                      unawaited(
                        HapticFeedback.mediumImpact(),
                      );
                      _showUpgrade(context);
                    },
                    message: 'Unlock Top 10 '
                        'with Locals Pass',
                    child: Column(
                      children: List.generate(
                        top6to10.length,
                        (i) => _LockedRestaurantPlaceholder(
                          rank: i + 6,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRestaurant(Restaurant restaurant) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RestaurantDetailScreen(
            restaurantId: restaurant.id,
          ),
        ),
      ),
    );
  }

  void _showUpgrade(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const UpgradeScreen(),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: isActive ? AppTheme.onAccent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder for locked restaurant slots that reveals
/// only the rank number, not the restaurant name/data.
class _LockedRestaurantPlaceholder extends StatelessWidget {

  const _LockedRestaurantPlaceholder({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(
        bottom: AppTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(
          AppTheme.radiusMd,
        ),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: AppTheme.headlineLarge.copyWith(
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
