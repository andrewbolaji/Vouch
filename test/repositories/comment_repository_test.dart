import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/models.dart';
import 'package:vouch/repositories/comment_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CommentRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = CommentRepository(firestore: fakeFirestore);
  });

  CollectionReference<Map<String, dynamic>> commentsRef(String restaurantId) =>
      fakeFirestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('comments');

  group('CommentRepository', () {
    group('getPage', () {
      test('returns empty list when no comments exist', () async {
        final result = await repository.getPage('r1');

        expect(result.comments, isEmpty);
        expect(result.nextCursor, isNull);
      });

      test('returns top-level comments only (excludes replies)', () async {
        final now = DateTime(2024, 1, 15);
        await commentsRef('r1').doc('c1').set({
          'userId': 'user1',
          'userName': 'Alice',
          'text': 'Great place!',
          'createdAt': Timestamp.fromDate(now),
          'parentId': null,
          'isInsider': false,
        });
        await commentsRef('r1').doc('c2').set({
          'userId': 'user2',
          'userName': 'Bob',
          'text': 'I agree!',
          'createdAt':
              Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
          'parentId': 'c1', // This is a reply
          'isInsider': false,
        });

        final result = await repository.getPage('r1');

        expect(result.comments, hasLength(1));
        expect(result.comments.first.id, 'c1');
        expect(result.comments.first.text, 'Great place!');
        expect(result.comments.first.restaurantId, 'r1');
      });

      test('returns comments ordered by createdAt descending', () async {
        final baseTime = DateTime(2024, 3);
        for (var i = 0; i < 5; i++) {
          await commentsRef('r1').doc('c$i').set({
            'userId': 'user1',
            'userName': 'Alice',
            'text': 'Comment $i',
            'createdAt': Timestamp.fromDate(
              baseTime.add(Duration(hours: i)),
            ),
            'parentId': null,
            'isInsider': false,
          });
        }

        final result = await repository.getPage('r1');

        expect(result.comments, hasLength(5));
        // Most recent first
        expect(result.comments.first.text, 'Comment 4');
        expect(result.comments.last.text, 'Comment 0');
      });

      test('pagination: first page returns cursor when more pages exist',
          () async {
        final baseTime = DateTime(2024, 6);
        for (var i = 0; i < 5; i++) {
          await commentsRef('r1').doc('c$i').set({
            'userId': 'user1',
            'userName': 'Alice',
            'text': 'Comment $i',
            'createdAt': Timestamp.fromDate(
              baseTime.add(Duration(hours: i)),
            ),
            'parentId': null,
            'isInsider': false,
          });
        }

        // Request page of size 3
        final result = await repository.getPage('r1', pageSize: 3);

        expect(result.comments, hasLength(3));
        expect(result.nextCursor, isNotNull);
      });

      test('pagination: cursor encodes the last document path', () async {
        // Verifies that the cursor returned is a valid base64 encoding of the
        // last document's reference path, which the repository uses to resume.
        final baseTime = DateTime(2024, 6);
        for (var i = 0; i < 3; i++) {
          await commentsRef('r1').doc('c$i').set({
            'userId': 'user1',
            'userName': 'Alice',
            'text': 'Comment $i',
            'createdAt': Timestamp.fromDate(
              baseTime.add(Duration(hours: i)),
            ),
            'parentId': null,
            'isInsider': false,
          });
        }

        final result = await repository.getPage('r1', pageSize: 3);
        expect(result.comments, hasLength(3));
        // Exactly pageSize results, so a cursor is produced
        expect(result.nextCursor, isNotNull);

        // Decode the cursor and verify it points to a valid Firestore path
        final decoded = utf8.decode(base64Decode(result.nextCursor!));
        expect(decoded, startsWith('restaurants/r1/comments/'));
      });

      test('pagination: no cursor returned when results fit in one page',
          () async {
        final baseTime = DateTime(2024, 6);
        for (var i = 0; i < 3; i++) {
          await commentsRef('r1').doc('c$i').set({
            'userId': 'user1',
            'userName': 'Alice',
            'text': 'Comment $i',
            'createdAt': Timestamp.fromDate(
              baseTime.add(Duration(hours: i)),
            ),
            'parentId': null,
            'isInsider': false,
          });
        }

        final result = await repository.getPage('r1');

        expect(result.comments, hasLength(3));
        expect(result.nextCursor, isNull);
      });
    });

    group('getReplies', () {
      test('returns empty list when no replies exist', () async {
        final replies = await repository.getReplies('r1', 'c1');
        expect(replies, isEmpty);
      });

      test('returns replies ordered by createdAt ascending', () async {
        final baseTime = DateTime(2024, 2, 10);
        await commentsRef('r1').doc('reply1').set({
          'userId': 'user2',
          'userName': 'Bob',
          'text': 'First reply',
          'createdAt': Timestamp.fromDate(baseTime),
          'parentId': 'c1',
          'isInsider': false,
        });
        await commentsRef('r1').doc('reply2').set({
          'userId': 'user3',
          'userName': 'Charlie',
          'text': 'Second reply',
          'createdAt': Timestamp.fromDate(
            baseTime.add(const Duration(minutes: 30)),
          ),
          'parentId': 'c1',
          'isInsider': true,
        });

        final replies = await repository.getReplies('r1', 'c1');

        expect(replies, hasLength(2));
        expect(replies[0].text, 'First reply');
        expect(replies[1].text, 'Second reply');
        expect(replies[1].isInsider, true);
        expect(replies[0].restaurantId, 'r1');
      });

      test('does not return replies for a different parent', () async {
        final now = DateTime(2024, 4);
        await commentsRef('r1').doc('reply1').set({
          'userId': 'user2',
          'userName': 'Bob',
          'text': 'Reply to c1',
          'createdAt': Timestamp.fromDate(now),
          'parentId': 'c1',
          'isInsider': false,
        });
        await commentsRef('r1').doc('reply2').set({
          'userId': 'user3',
          'userName': 'Charlie',
          'text': 'Reply to c2',
          'createdAt': Timestamp.fromDate(now),
          'parentId': 'c2',
          'isInsider': false,
        });

        final replies = await repository.getReplies('r1', 'c1');

        expect(replies, hasLength(1));
        expect(replies.first.text, 'Reply to c1');
      });
    });

    group('add', () {
      test('adds a comment to the subcollection', () async {
        final comment = Comment(
          id: '',
          restaurantId: 'r1',
          userId: 'user1',
          userName: 'Alice',
          text: 'Amazing food!',
          createdAt: DateTime(2024, 5),
        );

        await repository.add('r1', comment);

        final snapshot = await commentsRef('r1').get();
        expect(snapshot.docs, hasLength(1));
        expect(snapshot.docs.first.data()['text'], 'Amazing food!');
        expect(snapshot.docs.first.data()['userId'], 'user1');
      });
    });

    group('delete', () {
      test('deletes a comment by ID', () async {
        await commentsRef('r1').doc('c1').set({
          'userId': 'user1',
          'userName': 'Alice',
          'text': 'To be deleted',
          'createdAt': Timestamp.fromDate(DateTime(2024)),
          'parentId': null,
          'isInsider': false,
        });

        await repository.delete('r1', 'c1');

        final doc = await commentsRef('r1').doc('c1').get();
        expect(doc.exists, false);
      });

      test('does not throw when deleting a non-existent comment', () async {
        // Firestore delete on non-existent doc is a no-op
        await expectLater(
          repository.delete('r1', 'nonexistent'),
          completes,
        );
      });
    });
  });
}
