import 'package:flutter/material.dart';
import 'package:vouch/widgets/restaurant_image.dart';

/// Layout constants for the split hero.
const double kHeroPrimaryRatio = 0.61;
const double kHeroGap = 2.0;

/// Adaptive detail hero for the restaurant detail screen.
///
/// Given a list of [ImageSource]s (1 or 2):
/// - One image: full-bleed hero, identical to the original layout.
/// - Two images: split layout with primary on the left at [kHeroPrimaryRatio]
///   width and secondary on the right, separated by a [kHeroGap] pixel gap.
///   Both are cover-cropped to the same height.
///
/// The widget takes a generic list of [ImageSource]s so the real multi-photo
/// path (Firestore photos subcollection) can feed it later without changing
/// this widget.
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
    if (images.length < 2) {
      return _singleHero();
    }
    return _splitHero();
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
            SizedBox(width: kHeroGap),
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
