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
  final _scrollController = ScrollController();
  final _top10Key = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onToggleTop10(bool show) {
    unawaited(HapticFeedback.selectionClick());
    final wasOff = !_showTop10;
    setState(() => _showTop10 = show);
    if (show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _top10Key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
          );
        }
      });
      // Auto-pop paywall for free users on transition into Top 10
      if (wasOff) {
        final membership = context.read<MembershipProvider>();
        if (!membership.canViewTop10) {
          Future<void>.delayed(
            const Duration(milliseconds: 300),
            () {
              if (mounted) _showUpgrade(context);
            },
          );
        }
      }
    }
  }

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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Anton city name
              Text(city.displayName, style: AppTheme.displayLarge),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                city.description,
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Segmented toggle (square, matches cards)
              Row(
                children: [
                  _ToggleButton(
                    label: 'Top 5',
                    isActive: !_showTop10,
                    onTap: () => _onToggleTop10(false),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _ToggleButton(
                    label: 'Top 10',
                    isActive: _showTop10,
                    showLock: !membership.canViewTop10,
                    onTap: () => _onToggleTop10(true),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Top 5 restaurant list
              ...top5.map(
                (r) => RestaurantCard(
                  restaurant: r,
                  onTap: () => _openRestaurant(r),
                ),
              ),
              // Top 10 section with animated reveal
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _showTop10 && top6to10.isNotEmpty
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: Column(
                          key: _top10Key,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppTheme.spacingSm),
                            // Section header
                            _Top10Header(
                              isLocked: !membership.canViewTop10,
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
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
                                source: 'top10',
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
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
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

/// Section header for ranks 6 to 10.
class _Top10Header extends StatelessWidget {
  const _Top10Header({required this.isLocked});
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'RANKS 6 TO 10',
          style: AppTheme.labelMedium.copyWith(
            color: isLocked ? AppTheme.goldInk : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        if (isLocked) ...[
          const SizedBox(width: AppTheme.spacingXs),
          Icon(
            Icons.lock_outline,
            color: AppTheme.goldInk,
            size: 14,
          ),
        ],
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showLock = false,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: showLock ? '$label, locked, upgrade to view' : label,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isActive ? AppTheme.accent : AppTheme.borderColor,
              width: AppTheme.borderInkWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTheme.labelMedium.copyWith(
                  color: isActive
                      ? AppTheme.onAccent
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showLock) ...[
                const SizedBox(width: AppTheme.spacingXs),
                Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: isActive
                      ? AppTheme.onAccent
                      : AppTheme.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for locked restaurant slots.
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
      decoration: AppTheme.cardDecoration,
      child: Center(
        child: Text(
          '#$rank',
          style: AppTheme.rankDisplay.copyWith(
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
