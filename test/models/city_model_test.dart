import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/city.dart';

void main() {
  Map<String, dynamic> cityJson() => <String, dynamic>{
        'id': 'houston',
        'name': 'Houston',
        'state': 'TX',
        'imageUrl': 'https://example.com/houston.jpg',
        'description': 'Big city, bigger plates.',
        'restaurantCount': 10,
        'status': 'live',
      };

  group('City model, baselineWeight', () {
    test('an absent field means the list is still opening, not expired', () {
      // The trap, and the reason the default is 1 rather than 0.
      // recomputeAllRanks skips a city with zero votes entirely, so it
      // never writes baselineWeight there, so the field is absent on
      // exactly the cities whose curated order is fully in force. A
      // default of 0 would hide the opening-list line on launch day,
      // the one day it is most true.
      final city = City.fromJson(cityJson());

      expect(city.baselineWeight, 1.0);
      expect(city.isOpeningList, isTrue);
    });

    test('a written zero means the curation has expired', () {
      final city = City.fromJson(cityJson()..['baselineWeight'] = 0);

      expect(city.baselineWeight, 0);
      expect(city.isOpeningList, isFalse);
    });

    test('a partial weight still counts as opening', () {
      final city = City.fromJson(cityJson()..['baselineWeight'] = 0.35);

      expect(city.baselineWeight, closeTo(0.35, 0.0001));
      expect(city.isOpeningList, isTrue);
    });

    test('parses an integer weight, which is what Firestore sends at 1', () {
      // Firestore stores 1.0 as an integer and hands it back as int,
      // so a plain `as double` cast here would throw on the most
      // common value in the collection.
      final city = City.fromJson(cityJson()..['baselineWeight'] = 1);

      expect(city.baselineWeight, 1.0);
      expect(city.isOpeningList, isTrue);
    });
  });
}
