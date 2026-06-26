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

    test('round-trip: toJson then fromJson preserves all new fields', () {
      const original = Restaurant(
        id: 'hou-ChIJabc',
        cityId: 'houston',
        name: 'Test Truck',
        cuisine: 'BBQ',
        imageUrl: 'placeholder://restaurant',
        description: 'A test restaurant.',
        rank: kUnrankedRank,
        priceLevel: 3,
        placeId: 'ChIJabc123',
        isMobileVenue: true,
        openingHours: ['Monday: 11:00 AM - 9:00 PM', 'Tuesday: Closed'],
        displayOrder: 7,
      );

      final json = original.toJson();
      final restored = Restaurant.fromJson(json);

      expect(restored.placeId, 'ChIJabc123');
      expect(restored.isMobileVenue, isTrue);
      expect(restored.openingHours, hasLength(2));
      expect(restored.openingHours.first, 'Monday: 11:00 AM - 9:00 PM');
      expect(restored.displayOrder, 7);
      expect(restored.isUnranked, isTrue);
      // Full equality (all fields, including old ones)
      expect(restored, equals(original));
    });

    test('toJson emits all new fields', () {
      const r = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Test',
        cuisine: 'Test',
        imageUrl: '',
        description: '',
        rank: kUnrankedRank,
        placeId: 'ChIJxyz',
        isMobileVenue: true,
        openingHours: ['Mon: 11-9'],
        displayOrder: 3,
      );

      final json = r.toJson();

      expect(json['placeId'], 'ChIJxyz');
      expect(json['isMobileVenue'], isTrue);
      expect(json['openingHours'], ['Mon: 11-9']);
      expect(json['displayOrder'], 3);
    });

    test('copyWith changes each new field independently', () {
      const base = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Test',
        cuisine: 'Test',
        imageUrl: '',
        description: '',
        rank: kUnrankedRank,
      );

      final withPlaceId = base.copyWith(placeId: 'ChIJ999');
      expect(withPlaceId.placeId, 'ChIJ999');
      expect(withPlaceId.isMobileVenue, isFalse); // unchanged

      final withMobile = base.copyWith(isMobileVenue: true);
      expect(withMobile.isMobileVenue, isTrue);
      expect(withMobile.placeId, isNull); // unchanged

      final withHours = base.copyWith(openingHours: ['Mon: 11-9']);
      expect(withHours.openingHours, ['Mon: 11-9']);

      final withOrder = base.copyWith(displayOrder: 42);
      expect(withOrder.displayOrder, 42);
      expect(withOrder.rank, kUnrankedRank); // unchanged
    });
  });
}
