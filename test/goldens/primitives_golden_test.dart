import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/premium_badge.dart';
import 'package:vouch/widgets/rating_pill.dart';

import 'golden_harness.dart';

void main() {
  setUpAll(setUpGoldens);

  testWidgets('Golden: rank chips (1 crowned, 2 flame, 4 muted)',
      (tester) async {
    await pumpForGolden(
      tester,
      Scaffold(
        backgroundColor: AppTheme.background,
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RatingPill(rank: 1),
              RatingPill(rank: 2),
              RatingPill(rank: 4),
            ],
          ),
        ),
      ),
      size: const Size(400, 120),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('baselines/rank_chips.png'),
    );
  });

  testWidgets('Golden: rank chips large (detail view)', (tester) async {
    await pumpForGolden(
      tester,
      Scaffold(
        backgroundColor: AppTheme.background,
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RatingPill(rank: 1, isLarge: true),
              RatingPill(rank: 3, isLarge: true),
              RatingPill(rank: 5, isLarge: true),
            ],
          ),
        ),
      ),
      size: const Size(400, 120),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('baselines/rank_chips_large.png'),
    );
  });

  testWidgets('Golden: buttons and premium badge', (tester) async {
    await pumpForGolden(
      tester,
      Scaffold(
        backgroundColor: AppTheme.background,
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: AppTheme.accentButtonStyle,
                child: Text(
                  'Primary button',
                  style: AppTheme.buttonText.copyWith(
                    color: AppTheme.onAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: AppTheme.secondaryButtonStyle,
                child: Text('Secondary button', style: AppTheme.buttonText),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  PremiumBadge(),
                  SizedBox(width: 12),
                  PremiumBadge(label: 'Insider'),
                  SizedBox(width: 12),
                  PremiumBadge(label: 'Free'),
                ],
              ),
            ],
          ),
        ),
      ),
      size: const Size(390, 260),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('baselines/buttons_and_badges.png'),
    );
  });

  testWidgets('Golden: toggle buttons (Top 5 active, Top 10 active)',
      (tester) async {
    await pumpForGolden(
      tester,
      Scaffold(
        backgroundColor: AppTheme.background,
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _TogglePill(label: 'Top 5', isActive: true),
                  SizedBox(width: 8),
                  _TogglePill(label: 'Top 10', isActive: false),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _TogglePill(label: 'Top 5', isActive: false),
                  SizedBox(width: 8),
                  _TogglePill(label: 'Top 10', isActive: true),
                ],
              ),
            ],
          ),
        ),
      ),
      size: const Size(390, 180),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('baselines/toggle_states.png'),
    );
  });
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.label, required this.isActive});
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Text(
        label,
        style: AppTheme.labelMedium.copyWith(
          color: isActive ? AppTheme.onAccent : AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
