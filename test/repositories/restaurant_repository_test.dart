import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/repositories/restaurant_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RestaurantRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = RestaurantRepository(firestore: fakeFirestore);
  });

  Future<void> seedRestaurants(String cityId, int count) async {
    for (var i = 1; i <= count; i++) {
      await fakeFirestore.collection('restaurants').doc('r$i').set({
        'cityId': cityId,
        'name': 'Restaurant $i',
        'cuisine': 'Italian',
        'imageUrl': 'https://example.com/r$i.jpg',
        'description': 'Description for restaurant $i',
        'rank': i,
        'voteCount': 100 - i,
        'priceLevel': 2.0,
        'locations': <String>[],
        'vibeTags': <String>['cozy'],
      });
    }
  }

  group('RestaurantRepository', () {
    group('getForCity', () {
      test('returns empty list when no restaurants exist for city', () async {
        final restaurants = await repository.getForCity(
          'nonexistent_city',
          canViewTop10: true,
        );
        expect(restaurants, isEmpty);
      });

      test('returns all restaurants when canViewTop10 is true', () async {
        await seedRestaurants('city1', 10);

        final restaurants = await repository.getForCity(
          'city1',
          canViewTop10: true,
        );

        expect(restaurants, hasLength(10));
        // Verify ordered by rank ascending
        for (var i = 0; i < restaurants.length - 1; i++) {
          expect(restaurants[i].rank, lessThan(restaurants[i + 1].rank));
        }
      });

      test('returns only rank <= 5 when canViewTop10 is false', () async {
        await seedRestaurants('city1', 10);

        final restaurants = await repository.getForCity(
          'city1',
          canViewTop10: false,
        );

        expect(restaurants, hasLength(5));
        for (final r in restaurants) {
          expect(r.rank, lessThanOrEqualTo(5));
        }
      });

      test('does not return restaurants from other cities', () async {
        await seedRestaurants('city1', 3);
        await fakeFirestore.collection('restaurants').doc('other1').set({
          'cityId': 'city2',
          'name': 'Other Restaurant',
          'cuisine': 'French',
          'imageUrl': 'https://example.com/other.jpg',
          'description': 'A different city',
          'rank': 1,
          'voteCount': 50,
          'priceLevel': 3.0,
          'locations': <String>[],
          'vibeTags': <String>[],
        });

        final restaurants = await repository.getForCity(
          'city1',
          canViewTop10: true,
        );

        expect(restaurants, hasLength(3));
        for (final r in restaurants) {
          expect(r.cityId, 'city1');
        }
      });

      test('strips insiderTip and whatToOrder from returned restaurants',
          () async {
        await fakeFirestore.collection('restaurants').doc('r1').set({
          'cityId': 'city1',
          'name': 'Test Restaurant',
          'cuisine': 'Japanese',
          'imageUrl': 'https://example.com/test.jpg',
          'description': 'A test restaurant',
          'rank': 1,
          'voteCount': 10,
          'priceLevel': 2.0,
          'locations': <String>[],
          'vibeTags': <String>[],
          'insiderTip': 'Legacy tip that should be stripped',
          'whatToOrder': 'Legacy order that should be stripped',
        });

        final restaurants = await repository.getForCity(
          'city1',
          canViewTop10: true,
        );

        expect(restaurants.first.insiderTip, isNull);
        expect(restaurants.first.whatToOrder, isNull);
      });
    });

    group('getById', () {
      test('returns null when restaurant does not exist', () async {
        final restaurant = await repository.getById('nonexistent');
        expect(restaurant, isNull);
      });

      test('returns the restaurant when it exists', () async {
        await fakeFirestore.collection('restaurants').doc('r1').set({
          'cityId': 'city1',
          'name': 'Sushi Place',
          'cuisine': 'Japanese',
          'imageUrl': 'https://example.com/sushi.jpg',
          'description': 'Best sushi in town',
          'rank': 2,
          'voteCount': 42,
          'priceLevel': 3.0,
          'locations': [
            {
              'name': 'Downtown',
              'address': '123 Main St',
              'latitude': 40.7,
              'longitude': -74.0,
            }
          ],
          'vibeTags': ['upscale', 'date-night'],
        });

        final restaurant = await repository.getById('r1');

        expect(restaurant, isNotNull);
        expect(restaurant!.id, 'r1');
        expect(restaurant.name, 'Sushi Place');
        expect(restaurant.cuisine, 'Japanese');
        expect(restaurant.rank, 2);
        expect(restaurant.voteCount, 42);
        expect(restaurant.priceLevel, 3.0);
        expect(restaurant.locations, hasLength(1));
        expect(restaurant.locations.first.name, 'Downtown');
        expect(restaurant.vibeTags, ['upscale', 'date-night']);
      });
    });

    group('getInsiderNotes', () {
      test('returns null when no insider notes exist', () async {
        await fakeFirestore.collection('restaurants').doc('r1').set({
          'cityId': 'city1',
          'name': 'Test',
          'cuisine': 'Italian',
          'imageUrl': 'https://example.com/t.jpg',
          'description': 'Test',
          'rank': 1,
          'voteCount': 0,
          'priceLevel': 2.0,
          'locations': <String>[],
          'vibeTags': <String>[],
        });

        final notes = await repository.getInsiderNotes('r1');
        expect(notes, isNull);
      });

      test('returns insider notes when they exist', () async {
        await fakeFirestore
            .collection('restaurants')
            .doc('r1')
            .collection('insiderNotes')
            .doc('notes')
            .set({
          'whatToOrder': 'The truffle pasta',
          'insiderTip': 'Ask for the secret menu',
        });

        final notes = await repository.getInsiderNotes('r1');

        expect(notes, isNotNull);
        expect(notes!.restaurantId, 'r1');
        expect(notes.whatToOrder, 'The truffle pasta');
        expect(notes.insiderTip, 'Ask for the secret menu');
      });

      test('returns insider notes with only partial data', () async {
        await fakeFirestore
            .collection('restaurants')
            .doc('r1')
            .collection('insiderNotes')
            .doc('notes')
            .set({
          'whatToOrder': 'The lobster roll',
        });

        final notes = await repository.getInsiderNotes('r1');

        expect(notes, isNotNull);
        expect(notes!.whatToOrder, 'The lobster roll');
        expect(notes.insiderTip, isNull);
      });
    });
  });
}
