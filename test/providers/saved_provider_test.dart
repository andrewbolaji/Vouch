import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/models/user_profile.dart';
import 'package:vouch/providers/saved_provider.dart';
import 'package:vouch/repositories/user_repository.dart';
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

class FakeUserRepository implements UserRepository {
  final Map<String, List<String>> _saves = {};
  AppException? shouldThrow;
  int updateSavedCallCount = 0;

  /// If set, the first call to [getSavedIds] awaits this completer
  /// before returning. Consumed after one use.
  Completer<void>? getSavedIdsGate;

  void seedSaves(String uid, List<String> ids) {
    _saves[uid] = List.from(ids);
  }

  @override
  Future<List<String>> getSavedIds(String uid) async {
    if (getSavedIdsGate != null) {
      final gate = getSavedIdsGate!;
      getSavedIdsGate = null;
      await gate.future;
    }
    if (shouldThrow != null) throw shouldThrow!;
    return List.from(_saves[uid] ?? []);
  }

  @override
  Future<void> updateSaved(
    String uid,
    String restaurantId, {
    required bool add,
  }) async {
    updateSavedCallCount++;
    if (shouldThrow != null) throw shouldThrow!;
    _saves.putIfAbsent(uid, () => []);
    if (add) {
      if (!_saves[uid]!.contains(restaurantId)) {
        _saves[uid]!.add(restaurantId);
      }
    } else {
      _saves[uid]!.remove(restaurantId);
    }
  }

  @override
  Future<UserProfile?> getUser(String uid) => throw UnimplementedError();
  @override
  Future<void> createUser(UserProfile profile) => throw UnimplementedError();
  @override
  Future<void> updateLastActive(String uid) => throw UnimplementedError();
  @override
  Future<void> addBlock(String blockerUid, String blockedUid) =>
      throw UnimplementedError();
  @override
  Future<void> removeBlock(String blockerUid, String blockedUid) =>
      throw UnimplementedError();
  @override
  Future<List<String>> getBlockedIds(String uid) =>
      throw UnimplementedError();
  @override
  Future<void> ensureUserDoc({
    required String uid,
    required String displayName,
    required String email,
  }) async {}
}

// -- Helpers --

/// Let async provider init settle.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AuthService auth;
  late FakeUserRepository repo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    auth = AuthService.mock();
    repo = FakeUserRepository();
  });

  group('SavedProvider', () {
    test('signed-out user has zero saves', () async {
      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );
      await _settle();

      expect(provider.savedCount, 0);
      expect(provider.isSaved('any-id'), isFalse);
      expect(provider.savedRestaurantIds, isEmpty);

      provider.dispose();
    });

    test('loads saved IDs from server on sign-in', () async {
      repo.seedSaves('user-a', ['hou-1', 'nyc-2']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.isSaved('nyc-2'), isTrue);
      expect(provider.savedCount, 2);

      provider.dispose();
    });

    test('clears all saves on sign-out', () async {
      repo.seedSaves('user-a', ['hou-1']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();
      expect(provider.savedCount, 1);

      auth.setMockUser(null);
      await _settle();

      expect(provider.savedCount, 0);
      expect(provider.isSaved('hou-1'), isFalse);

      provider.dispose();
    });

    test('cross-user isolation: B never sees A saves', () async {
      repo.seedSaves('user-a', ['hou-1', 'hou-11']);
      repo.seedSaves('user-b', ['nyc-1']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      // A signs in
      auth.setMockUser(_userA);
      await _settle();
      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.savedCount, 2);

      // A signs out
      auth.setMockUser(null);
      await _settle();
      expect(provider.savedCount, 0);

      // B signs in
      auth.setMockUser(_userB);
      await _settle();

      expect(provider.isSaved('nyc-1'), isTrue);
      expect(provider.isSaved('hou-1'), isFalse);
      expect(provider.isSaved('hou-11'), isFalse);
      expect(provider.savedCount, 1);

      provider.dispose();
    });

    test('toggleSaved calls updateSaved on the repo', () async {
      repo.seedSaves('user-a', []);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      final error = await provider.toggleSaved('hou-1');

      expect(error, isNull);
      expect(provider.isSaved('hou-1'), isTrue);
      expect(repo.updateSavedCallCount, 1);

      provider.dispose();
    });

    test('toggleSaved unsave calls updateSaved with add=false', () async {
      repo.seedSaves('user-a', ['hou-1']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();
      expect(provider.isSaved('hou-1'), isTrue);

      final error = await provider.toggleSaved('hou-1');

      expect(error, isNull);
      expect(provider.isSaved('hou-1'), isFalse);
      expect(repo.updateSavedCallCount, 1);

      provider.dispose();
    });

    test('toggleSaved rolls back on repo failure', () async {
      repo.seedSaves('user-a', []);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      // Make the repo fail
      repo.shouldThrow = const FirestoreWriteException();

      final error = await provider.toggleSaved('hou-1');

      expect(error, isA<FirestoreWriteException>());
      expect(provider.isSaved('hou-1'), isFalse); // rolled back

      provider.dispose();
    });

    test('toggleSaved rolls back unsave on failure', () async {
      repo.seedSaves('user-a', ['hou-1']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      repo.shouldThrow = const NetworkException();

      final error = await provider.toggleSaved('hou-1');

      expect(error, isA<NetworkException>());
      expect(provider.isSaved('hou-1'), isTrue); // rolled back

      provider.dispose();
    });

    test('toggleSaved while signed out returns PermissionDenied', () async {
      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );
      await _settle();

      final error = await provider.toggleSaved('hou-1');

      expect(error, isA<PermissionDenied>());
      expect(provider.isSaved('hou-1'), isFalse);

      provider.dispose();
    });

    test('savedRestaurantIds returns unmodifiable set', () async {
      repo.seedSaves('user-a', ['hou-1']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(
        () => provider.savedRestaurantIds.add('bad'),
        throwsUnsupportedError,
      );

      provider.dispose();
    });

    test('savedCountFor excludes orphaned IDs', () async {
      repo.seedSaves('user-a', ['hou-1', 'deleted-id']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.savedCount, 2);
      expect(
        provider.savedCountFor({'hou-1', 'hou-11'}),
        1,
      );

      provider.dispose();
    });

    test('pruneOrphans removes invalid IDs', () async {
      repo.seedSaves('user-a', ['hou-1', 'deleted-id', 'also-gone']);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();
      expect(provider.savedCount, 3);

      provider.pruneOrphans({'hou-1', 'hou-11', 'nyc-1'});

      expect(provider.savedCount, 1);
      expect(provider.isSaved('hou-1'), isTrue);
      expect(provider.isSaved('deleted-id'), isFalse);

      provider.dispose();
    });

    test('notifies listeners on toggle', () async {
      repo.seedSaves('user-a', []);

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.toggleSaved('hou-1');
      // At least 1 notification for the optimistic update
      expect(notifyCount, greaterThanOrEqualTo(1));

      provider.dispose();
    });

    test('offline fallback: loads from per-uid cache on server failure',
        () async {
      SharedPreferences.setMockInitialValues({
        'saved_restaurant_ids_user-a': ['cached-1', 'cached-2'],
      });

      repo.shouldThrow = const NetworkException();

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.isSaved('cached-1'), isTrue);
      expect(provider.isSaved('cached-2'), isTrue);
      expect(provider.savedCount, 2);

      provider.dispose();
    });

    test('stale auth guard: discards load if auth changed during load',
        () async {
      final gate = Completer<void>();
      repo
        ..seedSaves('user-a', ['hou-1'])
        ..seedSaves('user-b', ['nyc-1'])
        ..getSavedIdsGate = gate;

      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );

      // Sign in as A, load starts but blocks on gate
      auth.setMockUser(_userA);
      await _settle();

      // Switch to B before A completes (gate consumed, B loads immediately)
      auth.setMockUser(_userB);
      await _settle();

      // B's data is loaded
      expect(provider.isSaved('nyc-1'), isTrue);

      // Complete A's stale load
      gate.complete();
      await _settle();

      // A's data was discarded by stale guard
      expect(provider.isSaved('hou-1'), isFalse);
      expect(provider.isSaved('nyc-1'), isTrue);

      provider.dispose();
    });

    test('dispose removes auth listener', () async {
      final provider = SavedProvider(
        authService: auth,
        userRepository: repo,
      );
      await _settle();

      provider.dispose();

      // Changing auth after dispose should not throw or affect provider
      auth.setMockUser(_userA);
      await _settle();

      // Provider state unchanged (still empty from before dispose)
      expect(provider.savedCount, 0);
    });
  });
}
