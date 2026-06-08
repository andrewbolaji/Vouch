import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/repositories/vote_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VoteRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = VoteRepository(firestore: fakeFirestore);
  });

  DocumentReference<Map<String, dynamic>> voteDoc(
    String restaurantId,
    String userId,
  ) =>
      fakeFirestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('votes')
          .doc(userId);

  group('VoteRepository', () {
    group('hasVoted', () {
      test('returns false when user has not voted', () async {
        final result = await repository.hasVoted('r1', 'user1');
        expect(result, false);
      });

      test('returns true when user has voted', () async {
        await voteDoc('r1', 'user1').set({
          'createdAt': Timestamp.fromDate(DateTime(2024, 3, 1)),
        });

        final result = await repository.hasVoted('r1', 'user1');
        expect(result, true);
      });

      test('returns false for different user on same restaurant', () async {
        await voteDoc('r1', 'user1').set({
          'createdAt': Timestamp.fromDate(DateTime(2024, 3, 1)),
        });

        final result = await repository.hasVoted('r1', 'user2');
        expect(result, false);
      });

      test('returns false for same user on different restaurant', () async {
        await voteDoc('r1', 'user1').set({
          'createdAt': Timestamp.fromDate(DateTime(2024, 3, 1)),
        });

        final result = await repository.hasVoted('r2', 'user1');
        expect(result, false);
      });
    });

    group('vote', () {
      test('creates a vote document', () async {
        await repository.vote('r1', 'user1');

        final doc = await voteDoc('r1', 'user1').get();
        expect(doc.exists, true);
      });

      test('vote is reflected by hasVoted', () async {
        expect(await repository.hasVoted('r1', 'user1'), false);

        await repository.vote('r1', 'user1');

        expect(await repository.hasVoted('r1', 'user1'), true);
      });

      test('voting twice does not throw (idempotent set)', () async {
        await repository.vote('r1', 'user1');
        await expectLater(
          repository.vote('r1', 'user1'),
          completes,
        );
      });
    });

    group('unvote', () {
      test('removes a vote document', () async {
        await voteDoc('r1', 'user1').set({
          'createdAt': Timestamp.fromDate(DateTime(2024, 3, 1)),
        });

        await repository.unvote('r1', 'user1');

        final doc = await voteDoc('r1', 'user1').get();
        expect(doc.exists, false);
      });

      test('unvote is reflected by hasVoted', () async {
        await repository.vote('r1', 'user1');
        expect(await repository.hasVoted('r1', 'user1'), true);

        await repository.unvote('r1', 'user1');

        expect(await repository.hasVoted('r1', 'user1'), false);
      });

      test('unvoting when no vote exists does not throw', () async {
        await expectLater(
          repository.unvote('r1', 'user1'),
          completes,
        );
      });
    });

    group('vote and unvote flow', () {
      test('full lifecycle: vote, confirm, unvote, confirm', () async {
        // Initially not voted
        expect(await repository.hasVoted('r1', 'user1'), false);

        // Vote
        await repository.vote('r1', 'user1');
        expect(await repository.hasVoted('r1', 'user1'), true);

        // Unvote
        await repository.unvote('r1', 'user1');
        expect(await repository.hasVoted('r1', 'user1'), false);

        // Re-vote
        await repository.vote('r1', 'user1');
        expect(await repository.hasVoted('r1', 'user1'), true);
      });
    });
  });
}
