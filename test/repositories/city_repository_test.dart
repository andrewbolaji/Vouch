import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/repositories/city_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CityRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = CityRepository(firestore: fakeFirestore);
  });

  group('CityRepository', () {
    group('getCities', () {
      test('returns empty list when no cities exist', () async {
        final cities = await repository.getCities();
        expect(cities, isEmpty);
      });

      test('returns all cities ordered by name', () async {
        await fakeFirestore.collection('cities').doc('city1').set({
          'name': 'New York',
          'state': 'NY',
          'imageUrl': 'https://example.com/ny.jpg',
          'description': 'The Big Apple',
          'restaurantCount': 10,
        });
        await fakeFirestore.collection('cities').doc('city2').set({
          'name': 'Austin',
          'state': 'TX',
          'imageUrl': 'https://example.com/atx.jpg',
          'description': 'Keep Austin Weird',
          'restaurantCount': 5,
        });
        await fakeFirestore.collection('cities').doc('city3').set({
          'name': 'Chicago',
          'state': 'IL',
          'imageUrl': 'https://example.com/chi.jpg',
          'description': 'The Windy City',
          'restaurantCount': 8,
        });

        final cities = await repository.getCities();

        expect(cities, hasLength(3));
        expect(cities[0].name, 'Austin');
        expect(cities[1].name, 'Chicago');
        expect(cities[2].name, 'New York');
      });

      test('returns cities with correct fields populated', () async {
        await fakeFirestore.collection('cities').doc('city1').set({
          'name': 'Portland',
          'state': 'OR',
          'imageUrl': 'https://example.com/pdx.jpg',
          'description': 'Rose City',
          'restaurantCount': 7,
        });

        final cities = await repository.getCities();

        expect(cities, hasLength(1));
        final city = cities.first;
        expect(city.id, 'city1');
        expect(city.name, 'Portland');
        expect(city.state, 'OR');
        expect(city.imageUrl, 'https://example.com/pdx.jpg');
        expect(city.description, 'Rose City');
        expect(city.restaurantCount, 7);
      });
    });

    group('getById', () {
      test('returns null when city does not exist', () async {
        final city = await repository.getById('nonexistent');
        expect(city, isNull);
      });

      test('returns the city when it exists', () async {
        await fakeFirestore.collection('cities').doc('city1').set({
          'name': 'Miami',
          'state': 'FL',
          'imageUrl': 'https://example.com/mia.jpg',
          'description': 'Magic City',
          'restaurantCount': 6,
        });

        final city = await repository.getById('city1');

        expect(city, isNotNull);
        expect(city!.id, 'city1');
        expect(city.name, 'Miami');
        expect(city.state, 'FL');
        expect(city.imageUrl, 'https://example.com/mia.jpg');
        expect(city.description, 'Magic City');
        expect(city.restaurantCount, 6);
      });

      test('returns correct city when multiple cities exist', () async {
        await fakeFirestore.collection('cities').doc('city1').set({
          'name': 'Denver',
          'state': 'CO',
          'imageUrl': 'https://example.com/den.jpg',
          'description': 'Mile High City',
          'restaurantCount': 4,
        });
        await fakeFirestore.collection('cities').doc('city2').set({
          'name': 'Seattle',
          'state': 'WA',
          'imageUrl': 'https://example.com/sea.jpg',
          'description': 'Emerald City',
          'restaurantCount': 9,
        });

        final city = await repository.getById('city2');

        expect(city, isNotNull);
        expect(city!.name, 'Seattle');
      });
    });
  });
}
