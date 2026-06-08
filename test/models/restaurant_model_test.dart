import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/restaurant.dart';

void main() {
  group('Restaurant model', () {
    test('fromJson without new fields parses with safe defaults', () {
      // Simulates a Firestore doc written before the placeId, isMobileVenue,
      // openingHours, and displayOrder fields existed.
      final json = <String, dynamic>{
        'id': 'hou-1',
        'cityId': 'houston',
        'name': 'Turkey Leg Hut',
        'cuisine': 'Soul Food',
        'imageUrl': 'https://example.com/photo.jpg',
        'description': 'A Houston classic.',
        'rank': 1,
        'voteCount': 100,
        'priceLevel': 2.0,
        'locations': <dynamic>[],
        'vibeTags': <dynamic>['Casual'],
      };

      final restaurant = Restaurant.fromJson(json);

      expect(restaurant.placeId, isNull);
      expect(restaurant.isMobileVenue, isFalse);
      expect(restaurant.openingHours, isEmpty);
      expect(restaurant.displayOrder, 0);
      // Existing fields still parse correctly
      expect(restaurant.name, 'Turkey Leg Hut');
      expect(restaurant.rank, 1);
      expect(restaurant.voteCount, 100);
    });

    test('fromJson with new fields parses correctly', () {
      final json = <String, dynamic>{
        'id': 'hou-ChIJ123',
        'cityId': 'houston',
        'name': 'Rosemeyer',
        'cuisine': 'BBQ',
        'imageUrl': 'placeholder://restaurant',
        'description': '',
        'rank': kUnrankedRank,
        'voteCount': 0,
        'priceLevel': 2.0,
        'locations': <dynamic>[],
        'vibeTags': <dynamic>[],
        'placeId': 'ChIJ123abc',
        'isMobileVenue': true,
        'openingHours': <dynamic>['Monday: 11:00 AM - 9:00 PM'],
        'displayOrder': 42,
      };

      final restaurant = Restaurant.fromJson(json);

      expect(restaurant.placeId, 'ChIJ123abc');
      expect(restaurant.isMobileVenue, isTrue);
      expect(restaurant.openingHours, ['Monday: 11:00 AM - 9:00 PM']);
      expect(restaurant.displayOrder, 42);
      expect(restaurant.isUnranked, isTrue);
    });

    test('isUnranked returns true for kUnrankedRank', () {
      const r = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Test',
        cuisine: 'Test',
        imageUrl: '',
        description: '',
        rank: kUnrankedRank,
      );
      expect(r.isUnranked, isTrue);
    });

    test('isUnranked returns false for ranked restaurants', () {
      const r = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Test',
        cuisine: 'Test',
        imageUrl: '',
        description: '',
        rank: 5,
      );
      expect(r.isUnranked, isFalse);
    });
  });
}
