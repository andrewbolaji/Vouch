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

    testWidgets('shows the vote count at zero', (tester) async {
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

      // This asserted findsNothing until 2026-08-13. The count is now
      // always shown, because at launch every count is zero, and
      // hiding them meant the app displayed no vote count anywhere.
      // A voting app whose first screen shows no evidence that voting
      // exists is not communicating its own premise, and a list where
      // some cards carry a number and others carry nothing reads as
      // broken rather than as empty.
      expect(find.text('0 votes'), findsOneWidget);
      // Cuisine still shown
      expect(find.textContaining('Tacos'), findsOneWidget);
    });

    testWidgets('still hides the comment count at zero', (tester) async {
      // The asymmetry is deliberate, so it is pinned rather than left
      // to be "tidied up" later for consistency. A zero comment count
      // says nothing has been said, which is not a call to action and
      // is not part of the ranking premise.
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

      expect(find.text('0 votes'), findsOneWidget);
      expect(find.textContaining('comments'), findsNothing);
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

    testWidgets('shows comment badge when commentCount > 0', (tester) async {
      const restaurant = Restaurant(
        id: 'hou-1',
        cityId: 'houston',
        name: 'Mensho',
        cuisine: 'Ramen',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: 1,
        voteCount: 100,
        commentCount: 7,
      );

      await tester.pumpWidget(buildCard(restaurant));

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('hides comment badge when commentCount is 0', (tester) async {
      const restaurant = Restaurant(
        id: 'hou-11',
        cityId: 'houston',
        name: 'Tacos Los Brothers',
        cuisine: 'Mexican (Tacos)',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: 2,
        // commentCount defaults to 0
      );

      await tester.pumpWidget(buildCard(restaurant));

      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });
  });
}
