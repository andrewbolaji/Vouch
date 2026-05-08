import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/models/suggestion.dart';
import 'package:vouch/providers/suggestion_provider.dart';

void main() {
  group('SuggestionProvider', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with zero count', () {
      final provider = SuggestionProvider();
      expect(provider.todayCount, 0);
      expect(provider.canSubmitToday, isTrue);
      expect(provider.remainingToday, kDailySuggestionCap);
    });

    test('submitSuggestion increments count', () {
      final provider = SuggestionProvider();

      final success = provider.submitSuggestion(
        type: SuggestionType.general,
        text: 'Test suggestion',
      );

      expect(success, isTrue);
      expect(provider.todayCount, 1);
      expect(
        provider.remainingToday,
        kDailySuggestionCap - 1,
      );
    });

    test('enforces daily cap', () {
      final provider = SuggestionProvider();

      for (var i = 0; i < kDailySuggestionCap; i++) {
        expect(
          provider.submitSuggestion(
            type: SuggestionType.general,
            text: 'Suggestion $i',
          ),
          isTrue,
        );
      }

      expect(provider.canSubmitToday, isFalse);
      expect(provider.remainingToday, 0);

      final blocked = provider.submitSuggestion(
        type: SuggestionType.general,
        text: 'One too many',
      );
      expect(blocked, isFalse);
      expect(provider.todayCount, kDailySuggestionCap);
    });

    test('stores suggestions in list', () {
      final provider = SuggestionProvider();

      provider.submitSuggestion(
        type: SuggestionType.newRestaurant,
        text: 'Add Ramen Tatsu-Ya',
        cityId: 'houston',
      );

      expect(provider.suggestions.length, 1);
      expect(
        provider.suggestions.first.type,
        SuggestionType.newRestaurant,
      );
      expect(
        provider.suggestions.first.text,
        'Add Ramen Tatsu-Ya',
      );
      expect(provider.suggestions.first.cityId, 'houston');
    });

    test('suggestions list is unmodifiable', () {
      final provider = SuggestionProvider();
      expect(
        () => provider.suggestions.add(
          Suggestion(
            id: 'x',
            userId: 'x',
            type: SuggestionType.general,
            text: 'x',
            createdAt: DateTime.now(),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('notifies listeners on submit', () {
      final provider = SuggestionProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.submitSuggestion(
        type: SuggestionType.general,
        text: 'Test',
      );
      expect(notified, isTrue);
    });

    test('does not notify on rejected submit', () {
      final provider = SuggestionProvider();

      // Fill up the cap
      for (var i = 0; i < kDailySuggestionCap; i++) {
        provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'Fill $i',
        );
      }

      var notified = false;
      provider.addListener(() => notified = true);

      provider.submitSuggestion(
        type: SuggestionType.general,
        text: 'Rejected',
      );
      expect(notified, isFalse);
    });

    test('all suggestion types accepted', () {
      // Test each type individually with a fresh provider
      for (final type in SuggestionType.values) {
        final provider = SuggestionProvider();
        final success = provider.submitSuggestion(
          type: type,
          text: 'Test ${type.name}',
        );
        expect(success, isTrue);
      }
    });
  });
}
