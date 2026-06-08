import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/widgets/comment_tile.dart';
import 'package:vouch/widgets/restaurant_card.dart';

import '../helpers/test_app.dart';

const _testRestaurant = Restaurant(
  id: 'test-1',
  cityId: 'houston',
  name: 'Turkey Leg Hut',
  cuisine: 'Soul Food',
  imageUrl: 'https://example.com/img.jpg',
  description: 'Test description',
  rank: 1,
  voteCount: 100,
);

void main() {
  group('RestaurantCard accessibility', () {
    testWidgets('has Semantics label with rank, name, cuisine', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          RestaurantCard(
            restaurant: _testRestaurant,
            onTap: () {},
          ),
        ),
      );
      await pumpPastLoad(tester);

      final semantics = tester.getSemantics(
        find.byType(RestaurantCard),
      );
      expect(semantics.label, contains('#1'));
      expect(semantics.label, contains('Turkey Leg Hut'));
      expect(semantics.label, contains('Soul Food'));
    });
  });

  group('CommentTile accessibility', () {
    testWidgets('reply button has Semantics label', (tester) async {
      final comment = Comment(
        id: 'c1',
        restaurantId: 'r1',
        userId: 'u1',
        userName: 'TestUser',
        text: 'Great food',
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        buildTestApp(
          CommentTile(
            comment: comment,
            onReply: (_) {},
          ),
        ),
      );
      await pumpPastLoad(tester);

      final replyFinder = find.text('Reply');
      expect(replyFinder, findsOneWidget);

      // Verify Semantics wrapper exists around the reply button
      final semanticsFinder = find.ancestor(
        of: replyFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Reply to TestUser',
        ),
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
