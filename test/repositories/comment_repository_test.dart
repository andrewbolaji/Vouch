import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/repositories/comment_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CommentRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(null);
    repository = CommentRepository(firestore: fakeFirestore, auth: auth);
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

    group('submitComment', () {
      late MockFirebaseAuth mockAuth;
      late MockUser mockUser;

      setUp(() {
        mockAuth = MockFirebaseAuth();
        mockUser = MockUser();
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('user1');
        when(() => mockUser.getIdToken()).thenAnswer((_) async => 'tok');
      });

      test('sends correct HTTPS POST and returns the created comment',
          () async {
        Uri? capturedUri;
        Map<String, String>? capturedHeaders;
        String? capturedBody;

        final client = http_testing.MockClient((request) async {
          capturedUri = request.url;
          capturedHeaders = request.headers;
          capturedBody = request.body;
          return http.Response(
            jsonEncode({
              'result': {
                'id': 'c1',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'userName': 'Alice',
                'isInsider': false,
              },
            }),
            200,
          );
        });

        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        final comment = await repo.submitComment(
          restaurantId: 'r1',
          text: 'Amazing food!',
        );

        expect(
          capturedUri.toString(),
          'https://us-central1-majorcitymusteats.cloudfunctions.net'
              '/submitComment',
        );
        expect(capturedHeaders!['authorization'], 'Bearer tok');
        final sentData =
            (jsonDecode(capturedBody!) as Map<String, dynamic>)['data']
                as Map<String, dynamic>;
        expect(sentData['restaurantId'], 'r1');
        expect(sentData['text'], 'Amazing food!');
        expect(sentData.containsKey('parentId'), isFalse);

        expect(comment.id, 'c1');
        expect(comment.restaurantId, 'r1');
        expect(comment.userId, 'user1');
        expect(comment.userName, 'Alice');
        expect(comment.text, 'Amazing food!');
        expect(comment.isInsider, false);
        expect(comment.parentId, isNull);
      });

      test('includes parentId in the payload for a reply', () async {
        String? capturedBody;
        final client = http_testing.MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            jsonEncode({
              'result': {
                'id': 'c2',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'userName': 'Alice',
                'isInsider': false,
              },
            }),
            200,
          );
        });

        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        final reply = await repo.submitComment(
          restaurantId: 'r1',
          text: 'A reply',
          parentId: 'c1',
        );

        final sentData =
            (jsonDecode(capturedBody!) as Map<String, dynamic>)['data']
                as Map<String, dynamic>;
        expect(sentData['parentId'], 'c1');
        expect(reply.parentId, 'c1');
      });

      test('throws NetworkException when the request never reaches '
          'the server', () async {
        final client = http_testing.MockClient((_) async {
          throw const SocketException('no network');
        });
        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        expect(
          () => repo.submitComment(restaurantId: 'r1', text: 'Hi'),
          throwsA(isA<NetworkException>()),
        );
      });

      test('throws PermissionDenied when user is null', () async {
        when(() => mockAuth.currentUser).thenReturn(null);
        final client = http_testing.MockClient((_) async {
          fail('Should not make HTTP request');
        });
        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        expect(
          () => repo.submitComment(restaurantId: 'r1', text: 'Hi'),
          throwsA(isA<PermissionDenied>()),
        );
      });

      test('throws PermissionDenied on UNAUTHENTICATED error', () async {
        final client = http_testing.MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {'status': 'UNAUTHENTICATED', 'message': 'Expired.'},
            }),
            401,
          );
        });
        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        expect(
          () => repo.submitComment(restaurantId: 'r1', text: 'Hi'),
          throwsA(isA<PermissionDenied>()),
        );
      });

      test('throws CommentRejected on FAILED_PRECONDITION error', () async {
        final client = http_testing.MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {
                'status': 'FAILED_PRECONDITION',
                'message': 'That comment did not post.',
              },
            }),
            400,
          );
        });
        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        expect(
          () => repo.submitComment(restaurantId: 'r1', text: 'Bad text'),
          throwsA(isA<CommentRejected>()),
        );
      });

      test('throws FirestoreWriteException on unknown server error',
          () async {
        final client = http_testing.MockClient((_) async {
          return http.Response('Internal Server Error', 500);
        });
        final repo = CommentRepository(
          firestore: fakeFirestore,
          auth: mockAuth,
          httpClient: client,
        );

        expect(
          () => repo.submitComment(restaurantId: 'r1', text: 'Boom'),
          throwsA(isA<FirestoreWriteException>()),
        );
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
