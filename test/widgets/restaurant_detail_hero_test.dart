import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/widgets/restaurant_detail_hero.dart';
import 'package:vouch/widgets/restaurant_image.dart';

void main() {
  group('RestaurantDetailHero', () {
    testWidgets('renders single full-bleed hero when given one image',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: RestaurantDetailHero(
                images: [
                  ImageSource.network('https://example.com/photo.jpg'),
                ],
              ),
            ),
          ),
        ),
      );

      // Single image: no Row, just the image filling the space.
      // There should be exactly one CachedNetworkImage-backed widget.
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('renders split layout when given two images', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: RestaurantDetailHero(
                images: [
                  ImageSource.network('https://example.com/primary.jpg'),
                  ImageSource.network('https://example.com/secondary.jpg'),
                ],
              ),
            ),
          ),
        ),
      );

      // Split layout uses a Row with two SizedBox children and a gap.
      expect(find.byType(Row), findsOneWidget);

      // The Row should contain exactly 3 children:
      // primary SizedBox, gap SizedBox, secondary SizedBox
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, 3);

      // Primary is wider than secondary (61% vs 39% minus gap)
      final primaryBox = row.children[0] as SizedBox;
      final secondaryBox = row.children[2] as SizedBox;
      expect(primaryBox.width!, greaterThan(secondaryBox.width!));
    });

    testWidgets('split uses named constants for ratio and gap',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: RestaurantDetailHero(
                images: [
                  ImageSource.network('https://example.com/a.jpg'),
                  ImageSource.network('https://example.com/b.jpg'),
                ],
              ),
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      final gap = row.children[1] as SizedBox;
      expect(gap.width, kHeroGap);

      // Primary width should be approximately 61% of 400 minus half gap
      final primaryBox = row.children[0] as SizedBox;
      final expectedPrimary = 400 * kHeroPrimaryRatio - kHeroGap / 2;
      expect(primaryBox.width!, closeTo(expectedPrimary, 0.1));
    });
  });
}
