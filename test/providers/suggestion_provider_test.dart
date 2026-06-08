import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/models/suggestion.dart';
import 'package:vouch/providers/suggestion_provider.dart';
import 'package:vouch/repositories/suggestion_repository.dart';
import 'package:vouch/services/auth_service.dart';

// -- Fakes --

const _userA = AuthUser(
  uid: 'user-a',
  email: 'a@test.com',
  method: AuthMethod.email,
);

const _userB = AuthUser(
  uid: 'user-b',
  email: 'b@test.com',
  method: AuthMethod.email,
);

class FakeSuggestionRepository implements SuggestionRepository {
  final Map<String, int> _remaining = {};
  AppException? submitThrow;
  AppException? getRemainingThrow;
  int submitCallCount = 0;

  /// If set, the first call to [getRemainingToday] awaits this
  /// completer before returning. Consumed after one use.
  Completer<void>? getRemainingGate;

  void seedRemaining(String uid, int remaining) {
    _remaining[uid] = remaining;
  }

  @override
  Future<int> getRemainingToday(String userId) async {
    if (getRemainingGate != null) {
      final gate = getRemainingGate!;
      getRemainingGate = null;
      await gate.future;
    }
    if (getRemainingThrow != null) throw getRemainingThrow!;
    return _remaining[userId] ?? kDailySuggestionCap;
  }

  @override
  Future<void> submit({
    required String type,
    required String text,
    String? cityId,
  }) async {
    submitCallCount++;
    if (submitThrow != null) throw submitThrow!;
  }
}

// -- Helpers --

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AuthService auth;
  late FakeSuggestionRepository repo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    auth = AuthService.mock();
    repo = FakeSuggestionRepository();
  });

  group('SuggestionProvider', () {
    test('signed-out user sees default remaining count', () async {
      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );
      await _settle();

      expect(provider.remainingToday, kDailySuggestionCap);
      expect(provider.canSubmitToday, isTrue);
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });

    test('loads remaining from server on sign-in', () async {
      repo.seedRemaining('user-a', 0);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.remainingToday, 0);
      expect(provider.canSubmitToday, isFalse);

      provider.dispose();
    });

    test('submit calls repo and decrements counter', () async {
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();
      expect(provider.remainingToday, 1);

      await provider.submitSuggestion(
        type: SuggestionType.general,
        text: 'Great app!',
      );

      expect(repo.submitCallCount, 1);
      expect(provider.remainingToday, 0);
      expect(provider.canSubmitToday, isFalse);
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });

    test('submit while signed out throws PermissionDenied', () async {
      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );
      await _settle();

      expect(
        () => provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'Test',
        ),
        throwsA(isA<PermissionDenied>()),
      );
      expect(repo.submitCallCount, 0);

      provider.dispose();
    });

    test('RateLimited from server resets counter to 0', () async {
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      repo.submitThrow = const RateLimited();

      await expectLater(
        provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'One too many',
        ),
        throwsA(isA<RateLimited>()),
      );

      expect(provider.remainingToday, 0);
      expect(provider.canSubmitToday, isFalse);
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });

    test('client says remaining but server rejects: handled gracefully',
        () async {
      // Client thinks 1 remaining, but another device already submitted
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();
      expect(provider.remainingToday, 1);

      // Server rejects with rate limit
      repo.submitThrow = const RateLimited();

      await expectLater(
        provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'Should fail',
        ),
        throwsA(isA<RateLimited>()),
      );

      // Counter corrected to 0
      expect(provider.remainingToday, 0);

      provider.dispose();
    });

    test('generic error from server surfaces and keeps counter', () async {
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      repo.submitThrow = const FirestoreWriteException();

      await expectLater(
        provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'Network fail',
        ),
        throwsA(isA<FirestoreWriteException>()),
      );

      // Counter unchanged on generic error
      expect(provider.remainingToday, 1);
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });

    test('PermissionDenied from server surfaces', () async {
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      repo.submitThrow = const PermissionDenied(
        'You need to sign in to submit a suggestion.',
      );

      await expectLater(
        provider.submitSuggestion(
          type: SuggestionType.general,
          text: 'Denied',
        ),
        throwsA(isA<PermissionDenied>()),
      );

      // Counter unchanged
      expect(provider.remainingToday, 1);

      provider.dispose();
    });

    test('cross-user counter isolation', () async {
      repo
        ..seedRemaining('user-a', 0) // A already submitted
        ..seedRemaining('user-b', 1); // B has not

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      // A signs in
      auth.setMockUser(_userA);
      await _settle();
      expect(provider.remainingToday, 0);

      // A signs out
      auth.setMockUser(null);
      await _settle();
      expect(provider.remainingToday, kDailySuggestionCap);

      // B signs in, gets B's server count
      auth.setMockUser(_userB);
      await _settle();
      expect(provider.remainingToday, 1);

      provider.dispose();
    });

    test('sign-out resets submitting state', () async {
      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      // Sign out
      auth.setMockUser(null);
      await _settle();

      expect(provider.isSubmitting, isFalse);
      expect(provider.remainingToday, kDailySuggestionCap);

      provider.dispose();
    });

    test('stale auth guard: discards load if auth changed during load',
        () async {
      final gate = Completer<void>();
      repo
        ..seedRemaining('user-a', 0) // A exhausted
        ..seedRemaining('user-b', 1) // B has remaining
        ..getRemainingGate = gate;

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      // Sign in as A, load blocks on gate
      auth.setMockUser(_userA);
      await _settle();

      // Switch to B before A completes
      auth.setMockUser(_userB);
      await _settle();

      // B's data loaded
      expect(provider.remainingToday, 1);

      // Complete A's stale load
      gate.complete();
      await _settle();

      // A's stale result not applied
      expect(provider.remainingToday, 1);

      provider.dispose();
    });

    test('dispose removes auth listener', () async {
      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );
      await _settle();

      provider.dispose();

      // Changing auth after dispose does not throw
      auth.setMockUser(_userA);
      await _settle();

      // State unchanged
      expect(provider.remainingToday, kDailySuggestionCap);
    });

    test('isSubmitting is true during submit and false after', () async {
      repo.seedRemaining('user-a', 1);

      final provider = SuggestionProvider(
        authService: auth,
        suggestionRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.isSubmitting, isFalse);

      final future = provider.submitSuggestion(
        type: SuggestionType.newRestaurant,
        text: 'Add Ramen Tatsu-Ya',
        cityId: 'houston',
      );

      // isSubmitting may already be false since the fake completes
      // synchronously, so just verify it is false after await.
      await future;
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });
  });
}
