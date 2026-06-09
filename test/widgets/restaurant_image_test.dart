import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/config/demo_image_overrides.dart';
import 'package:vouch/models/restaurant.dart';
import 'package:vouch/widgets/restaurant_image.dart';

void main() {
  group('RestaurantImage.resolveDemoAsset', () {
    test('resolves to primary asset when enabled and name matches', () {
      final result = RestaurantImage.resolveDemoAsset('Truth BBQ');
      expect(result, isNotNull);
      expect(result, contains('assets/demo/'));
      expect(result, contains('Truth BBQ'));
      // Must be the primary (no suffix)
      expect(result, endsWith('Truth BBQ.png'));
    });

    test('match is case-insensitive', () {
      final lower = RestaurantImage.resolveDemoAsset('truth bbq');
      final upper = RestaurantImage.resolveDemoAsset('TRUTH BBQ');
      final mixed = RestaurantImage.resolveDemoAsset('Truth BBQ');

      expect(lower, isNotNull);
      expect(upper, isNotNull);
      expect(mixed, isNotNull);
      expect(lower, equals(upper));
      expect(upper, equals(mixed));
    });

    test('falls through when name is not in the map', () {
      final result = RestaurantImage.resolveDemoAsset('Unknown Restaurant');
      expect(result, isNull);
    });

    test('handles names with apostrophes', () {
      final result = RestaurantImage.resolveDemoAsset("Killen's Barbecue");
      expect(result, isNotNull);
      expect(result, contains("Killen's Barbecue"));
    });

    test('trims whitespace from name', () {
      final result = RestaurantImage.resolveDemoAsset('  Truth BBQ  ');
      expect(result, isNotNull);
    });
  });

  group('RestaurantImage.resolveImageSources', () {
    test('returns two sources for a restaurant with a pair', () {
      const restaurant = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Truth BBQ',
        cuisine: 'BBQ',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: 9999,
      );

      final sources = RestaurantImage.resolveImageSources(restaurant);
      expect(sources, hasLength(2));
      expect(sources[0].isAsset, isTrue);
      expect(sources[0].assetPath, endsWith('Truth BBQ.png'));
      expect(sources[1].isAsset, isTrue);
      expect(sources[1].assetPath, contains('Truth BBQ entrance'));
    });

    test('returns one source for a single-image restaurant', () {
      const restaurant = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Stick Talk',
        cuisine: 'BBQ',
        imageUrl: 'placeholder://restaurant',
        description: '',
        rank: 9999,
      );

      final sources = RestaurantImage.resolveImageSources(restaurant);
      expect(sources, hasLength(1));
      expect(sources[0].isAsset, isTrue);
    });

    test('falls through to network URL when name not in map', () {
      const restaurant = Restaurant(
        id: 'test',
        cityId: 'houston',
        name: 'Not In Demo',
        cuisine: 'Test',
        imageUrl: 'https://example.com/photo.jpg',
        description: '',
        rank: 9999,
      );

      final sources = RestaurantImage.resolveImageSources(restaurant);
      expect(sources, hasLength(1));
      expect(sources[0].isAsset, isFalse);
      expect(sources[0].networkUrl, 'https://example.com/photo.jpg');
    });
  });

  group('Demo override pairing', () {
    test('does not cross-match restaurants sharing a word', () {
      // "Killen's Barbecue" and "Killen's Steakhouse" share "Killen's"
      // but must resolve to different images.
      final barbecue = kDemoImageOverrides["killen's barbecue"];
      final steakhouse = kDemoImageOverrides["killen's steakhouse"];

      expect(barbecue, isNotNull);
      expect(steakhouse, isNotNull);
      expect(barbecue!.primary, contains("Killen's Barbecue"));
      expect(steakhouse!.primary, contains("Killen's Steakhouse"));
      // Neither pulls the other's files
      expect(barbecue.primary, isNot(contains('Steakhouse')));
      expect(steakhouse.primary, isNot(contains('Barbecue')));
      if (barbecue.secondary != null) {
        expect(barbecue.secondary, isNot(contains('Steakhouse')));
      }
      if (steakhouse.secondary != null) {
        expect(steakhouse.secondary, isNot(contains('Barbecue')));
      }
    });

    test('every entry has a non-empty primary', () {
      for (final entry in kDemoImageOverrides.entries) {
        expect(
          entry.value.primary.isNotEmpty,
          isTrue,
          reason: '${entry.key} has empty primary',
        );
      }
    });

    test('pairs have distinct primary and secondary paths', () {
      for (final entry in kDemoImageOverrides.entries) {
        if (entry.value.secondary != null) {
          expect(
            entry.value.primary,
            isNot(equals(entry.value.secondary)),
            reason: '${entry.key} has identical primary and secondary',
          );
        }
      }
    });
  });
}
