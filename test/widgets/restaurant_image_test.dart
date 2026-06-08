import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/restaurant.dart';
import 'package:vouch/widgets/restaurant_image.dart';

/// These tests exercise the static [RestaurantImage.resolveDemoAsset]
/// method, which is the single-point lookup that both the card and the
/// detail hero use. The method reads [kUseDemoImageOverrides] and
/// [kDemoImageOverrides] at call time, so we test against the current
/// compile-time values (kUseDemoImageOverrides = true in demo builds).

void main() {
  group('RestaurantImage.resolveDemoAsset', () {
    test('resolves to asset when enabled and name matches', () {
      // "turkey leg hut" is in kDemoImageOverrides
      final result = RestaurantImage.resolveDemoAsset('Turkey Leg Hut');
      expect(result, isNotNull);
      expect(result, contains('assets/demo/'));
      expect(result, contains('turkey_leg_hut'));
    });

    test('match is case-insensitive', () {
      final lower = RestaurantImage.resolveDemoAsset('turkey leg hut');
      final upper = RestaurantImage.resolveDemoAsset('TURKEY LEG HUT');
      final mixed = RestaurantImage.resolveDemoAsset('Turkey Leg Hut');

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
      final result = RestaurantImage.resolveDemoAsset("Killen's BBQ");
      expect(result, isNotNull);
      expect(result, contains('killens_bbq'));
    });

    test('trims whitespace from name', () {
      final result = RestaurantImage.resolveDemoAsset('  Turkey Leg Hut  ');
      expect(result, isNotNull);
    });
  });
}
