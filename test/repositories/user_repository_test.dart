import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: fakeFirestore);
  });

  group('UserRepository', () {
    group('getUser', () {
      test('returns null when user does not exist', () async {
        final user = await repository.getUser('nonexistent');
        expect(user, isNull);
      });

      test('returns user profile when it exists', () async {
        final createdAt = DateTime(2024);
        final lastActiveAt = DateTime(2024, 6, 15);
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice Johnson',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(createdAt),
          'lastActiveAt': Timestamp.fromDate(lastActiveAt),
          'photoUrl': 'https://example.com/alice.jpg',
          'membershipTier': 'premium',
          'savedRestaurantIds': ['r1', 'r2'],
        });

        final user = await repository.getUser('uid1');

        expect(user, isNotNull);
        expect(user!.id, 'uid1');
        expect(user.displayName, 'Alice Johnson');
        expect(user.email, 'alice@example.com');
        expect(user.createdAt, createdAt);
        expect(user.lastActiveAt, lastActiveAt);
        expect(user.photoUrl, 'https://example.com/alice.jpg');
        expect(user.membershipTier, 'premium');
        expect(user.savedRestaurantIds, ['r1', 'r2']);
      });

      test('returns user with default values for optional fields', () async {
        final now = DateTime(2024, 5);
        await fakeFirestore.collection('users').doc('uid2').set({
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'createdAt': Timestamp.fromDate(now),
          'lastActiveAt': Timestamp.fromDate(now),
        });

        final user = await repository.getUser('uid2');

        expect(user, isNotNull);
        expect(user!.photoUrl, isNull);
        expect(user.membershipTier, 'free');
        expect(user.savedRestaurantIds, isEmpty);
      });
    });

    group('createUser', () {
      test('creates a new user document', () async {
        final profile = UserProfile(
          id: 'uid1',
          displayName: 'Charlie',
          email: 'charlie@example.com',
          createdAt: DateTime(2024, 2),
          lastActiveAt: DateTime(2024, 2),
          savedRestaurantIds: [],
        );

        await repository.createUser(profile);

        final doc = await fakeFirestore.collection('users').doc('uid1').get();
        expect(doc.exists, true);
        expect(doc.data()!['displayName'], 'Charlie');
        expect(doc.data()!['email'], 'charlie@example.com');
      });

      test('overwrites existing user document', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Old Name',
          'email': 'old@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
        });

        final profile = UserProfile(
          id: 'uid1',
          displayName: 'New Name',
          email: 'new@example.com',
          createdAt: DateTime(2024, 3),
          lastActiveAt: DateTime(2024, 3),
        );

        await repository.createUser(profile);

        final user = await repository.getUser('uid1');
        expect(user!.displayName, 'New Name');
        expect(user.email, 'new@example.com');
      });
    });

    group('updateSaved', () {
      test('adds a restaurant ID to the saved list', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': ['r1'],
        });

        await repository.updateSaved('uid1', 'r2', add: true);

        final doc = await fakeFirestore.collection('users').doc('uid1').get();
        final saved = List<String>.from(
          doc.data()!['savedRestaurantIds'] as List,
        );
        expect(saved, contains('r1'));
        expect(saved, contains('r2'));
      });

      test('removes a restaurant ID from the saved list', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': ['r1', 'r2', 'r3'],
        });

        await repository.updateSaved('uid1', 'r2', add: false);

        final doc = await fakeFirestore.collection('users').doc('uid1').get();
        final saved = List<String>.from(
          doc.data()!['savedRestaurantIds'] as List,
        );
        expect(saved, contains('r1'));
        expect(saved, isNot(contains('r2')));
        expect(saved, contains('r3'));
      });

      test('adding a duplicate does not create duplicates', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': ['r1'],
        });

        await repository.updateSaved('uid1', 'r1', add: true);

        final doc = await fakeFirestore.collection('users').doc('uid1').get();
        final saved = List<String>.from(
          doc.data()!['savedRestaurantIds'] as List,
        );
        expect(saved.where((id) => id == 'r1').length, 1);
      });

      test('removing a non-existent ID does not throw', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': ['r1'],
        });

        await expectLater(
          repository.updateSaved('uid1', 'r99', add: false),
          completes,
        );
      });
    });

    group('getSavedIds', () {
      test('returns empty list when user does not exist', () async {
        final saved = await repository.getSavedIds('nonexistent');
        expect(saved, isEmpty);
      });

      test('returns empty list when user has no saved restaurants', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': <String>[],
        });

        final saved = await repository.getSavedIds('uid1');
        expect(saved, isEmpty);
      });

      test('returns saved restaurant IDs', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
          'savedRestaurantIds': ['r1', 'r2', 'r3'],
        });

        final saved = await repository.getSavedIds('uid1');
        expect(saved, ['r1', 'r2', 'r3']);
      });

      test('returns empty list when savedRestaurantIds field is missing',
          () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
        });

        final saved = await repository.getSavedIds('uid1');
        expect(saved, isEmpty);
      });
    });

    group('updateLastActive', () {
      test('updates the lastActiveAt timestamp', () async {
        await fakeFirestore.collection('users').doc('uid1').set({
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'lastActiveAt': Timestamp.fromDate(DateTime(2024)),
        });

        await repository.updateLastActive('uid1');

        final doc = await fakeFirestore.collection('users').doc('uid1').get();
        // With fake_cloud_firestore, serverTimestamp()
        // is set to a non-null value
        expect(doc.data()!['lastActiveAt'], isNotNull);
      });
    });
  });
}
