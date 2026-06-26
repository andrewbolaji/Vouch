import 'package:flutter/material.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/restaurant_image.dart';

/// Layout constants for the split hero.
const double kHeroPrimaryRatio = 0.61;
const double kHeroGap = 2;

/// Adaptive detail hero with ink scrim gradient for text legibility.
class RestaurantDetailHero extends StatelessWidget {
  const RestaurantDetailHero({
    required this.images,
    this.iconSize = 60,
    super.key,
  });

  final List<ImageSource> images;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.length < 2)
          _singleHero()
        else
          _splitHero(),
        // Ink scrim gradient (rule 2: ink-colored, never background)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.inkScrim.withValues(alpha: 0),
                  AppTheme.inkScrim.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _singleHero() {
    return buildImageFromSource(
      images.first,
      width: double.infinity,
      height: double.infinity,
      iconSize: iconSize,
    );
  }

  Widget _splitHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final primaryWidth = totalWidth * kHeroPrimaryRatio - kHeroGap / 2;
        final secondaryWidth =
            totalWidth * (1 - kHeroPrimaryRatio) - kHeroGap / 2;

        return Row(
          children: [
            SizedBox(
              width: primaryWidth,
              height: constraints.maxHeight,
              child: buildImageFromSource(
                images[0],
                width: primaryWidth,
                height: constraints.maxHeight,
                iconSize: iconSize,
              ),
            ),
            const SizedBox(width: kHeroGap),
            SizedBox(
              width: secondaryWidth,
              height: constraints.maxHeight,
              child: buildImageFromSource(
                images[1],
                width: secondaryWidth,
                height: constraints.maxHeight,
                iconSize: iconSize,
              ),
            ),
          ],
        );
      },
    );
  }
}
