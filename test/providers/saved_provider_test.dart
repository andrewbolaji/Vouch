import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/providers/saved_provider.dart';

void main() {
  group('SavedProvider', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty', () {
      final provider = SavedProvider();
      expect(provider.savedCount, 0);
      expect(provider.isSaved('any-id'), isFalse);
    });

    test('toggleSaved adds then removes', () {
      final provider = SavedProvider();

      provider.toggleSaved('hou-1');
      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.savedCount, 1);

      provider.toggleSaved('hou-1');
      expect(provider.isSaved('hou-1'), isFalse);
      expect(provider.savedCount, 0);
    });

    test('savedRestaurantIds returns unmodifiable set', () {
      final provider = SavedProvider();
      provider.toggleSaved('hou-1');

      expect(
        () => provider.savedRestaurantIds.add('bad'),
        throwsUnsupportedError,
      );
    });

    test('persistence round-trip', () async {
      SharedPreferences.setMockInitialValues({
        'saved_restaurant_ids': ['hou-1', 'nyc-2'],
      });

      final provider = SavedProvider();

      // Wait for async load
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );

      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.isSaved('nyc-2'), isTrue);
      expect(provider.isSaved('hou-3'), isFalse);
      expect(provider.savedCount, 2);
    });

    test('toggleSaved persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SavedProvider();
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );

      provider.toggleSaved('hou-1');

      // Wait for async save
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_restaurant_ids');
      expect(saved, contains('hou-1'));
    });

    test('notifies listeners on toggle', () {
      final provider = SavedProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.toggleSaved('hou-1');
      expect(notified, isTrue);
    });

    test('multiple saves tracked independently', () {
      final provider = SavedProvider();

      provider.toggleSaved('hou-1');
      provider.toggleSaved('nyc-1');
      provider.toggleSaved('la-1');

      expect(provider.savedCount, 3);
      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.isSaved('nyc-1'), isTrue);
      expect(provider.isSaved('la-1'), isTrue);

      provider.toggleSaved('nyc-1');
      expect(provider.savedCount, 2);
      expect(provider.isSaved('nyc-1'), isFalse);
    });

    test('savedCountFor excludes orphaned IDs', () {
      final provider = SavedProvider();
      provider.toggleSaved('hou-1');
      provider.toggleSaved('deleted-restaurant');

      expect(provider.savedCount, 2);
      expect(
        provider.savedCountFor({'hou-1', 'hou-2'}),
        1,
      );
    });

    test('pruneOrphans removes invalid IDs', () async {
      SharedPreferences.setMockInitialValues({
        'saved_restaurant_ids': [
          'hou-1',
          'deleted-id',
          'also-gone',
        ],
      });

      final provider = SavedProvider();
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );

      expect(provider.savedCount, 3);

      provider.pruneOrphans({'hou-1', 'hou-2', 'nyc-1'});

      expect(provider.savedCount, 1);
      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.isSaved('deleted-id'), isFalse);
    });
  });
}
