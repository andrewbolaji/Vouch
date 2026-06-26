import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/restaurant.dart';
import 'package:vouch/widgets/restaurant_card.dart';

void main() {
  Widget buildCard(Restaurant restaurant) {
    return MaterialApp(
      home: Scaffold(
        body: RestaurantCard(
          restaurant: restaurant,
          onTap: () {},
        ),
      ),
    );
  }

  group('RestaurantCard', () {
    testWidgets('shows rank badge and vote count for ranked restaurant',
        (tester) async {
      const restaurant = Restaurant(
        id: 'hou-1',
        cityId: 'houston',
        name: 'Turkey Leg Hut',
        cuisine: 'Soul Food',
        imageUrl: 'https://example.com/photo.jpg',
        description: 'A Houston classic.',
        rank: 3,
        voteCount: 500,
      );

      await tester.pumpWidget(buildCard(restaurant));

      // Rank badge visible
      expect(find.text('#3'), findsOneWidget);
      // Vote count visible
      expect(find.textContaining('votes'), findsOneWidget);
    });

    testWidgets('suppresses rank badge for unranked restaurant',
        (tester) async {
      const restaurant = Restaurant(
        id: 'hou-ChIJ123',
        cityId: 'houston',
        name: 'Rosemeyer',
        cuisine: 'BBQ',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: kUnrankedRank,
      );

      await tester.pumpWidget(buildCard(restaurant));

      // No rank badge (no #9999)
      expect(find.text('#$kUnrankedRank'), findsNothing);
      // Name still shown
      expect(find.text('Rosemeyer'), findsOneWidget);
    });

    testWidgets('suppresses vote count when zero', (tester) async {
      const restaurant = Restaurant(
        id: 'hou-ChIJ123',
        cityId: 'houston',
        name: 'Test Place',
        cuisine: 'Tacos',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: kUnrankedRank,
        priceLevel: 1,
      );

      await tester.pumpWidget(buildCard(restaurant));

      // No "0 votes" or "votes" text
      expect(find.textContaining('votes'), findsNothing);
      // Cuisine still shown
      expect(find.textContaining('Tacos'), findsOneWidget);
    });

    testWidgets('shows vote count when nonzero even if unranked',
        (tester) async {
      const restaurant = Restaurant(
        id: 'hou-ChIJ123',
        cityId: 'houston',
        name: 'Rising Star',
        cuisine: 'Mexican',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: kUnrankedRank,
        voteCount: 15,
      );

      await tester.pumpWidget(buildCard(restaurant));

      // Vote count shown (15 votes)
      expect(find.textContaining('votes'), findsOneWidget);
      // But no rank badge
      expect(find.text('#$kUnrankedRank'), findsNothing);
    });
  });
}
