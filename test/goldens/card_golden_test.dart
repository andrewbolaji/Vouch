import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/theme/app_theme.dart';
import 'package:vouch/widgets/restaurant_card.dart';

import 'golden_harness.dart';

Restaurant _makeRestaurant({
  required int rank,
  required String name,
  int voteCount = 100,
}) {
  return Restaurant(
    id: 'test-$rank',
    cityId: 'houston',
    name: name,
    cuisine: 'Test Cuisine',
    imageUrl: 'placeholder://restaurant',
    description: 'A test restaurant.',
    rank: rank,
    voteCount: voteCount,
    locations: const [
      RestaurantLocation(name: 'Downtown', address: '123 Main St'),
    ],
  );
}

void main() {
  setUpAll(setUpGoldens);

  testWidgets(
      'Golden: restaurant cards (rank 1 crowned, rank 2 flame, rank 5 muted)',
      (tester) async {
    await pumpForGolden(
      tester,
      Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              RestaurantCard(
                restaurant: _makeRestaurant(
                  rank: 1,
                  name: 'Mensho',
                  voteCount: 2847,
                ),
                onTap: () {},
              ),
              RestaurantCard(
                restaurant: _makeRestaurant(
                  rank: 2,
                  name: 'Tacos Los Brothers',
                  voteCount: 0,
                ),
                onTap: () {},
              ),
              RestaurantCard(
                restaurant: _makeRestaurant(
                  rank: 5,
                  name: 'Corkscrew BBQ',
                  voteCount: 0,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      size: const Size(420, 480),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('baselines/restaurant_cards.png'),
    );
  });
}
