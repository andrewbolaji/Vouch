import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/repositories/suggestion_repository.dart';

// -- Mocks --

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('SuggestionRepository.submit', () {
    test('sends correct HTTPS POST and succeeds on 200', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'test-token');

      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      String? capturedBody;

      final client = http_testing.MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = request.body;
        return http.Response(jsonEncode({'result': null}), 200);
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore,
        auth: mockAuth,
        httpClient: client,
      );

      await repo.submit(type: 'general', text: 'Great app!', cityId: 'htx');

      expect(
        capturedUri.toString(),
        'https://us-central1-majorcitymusteats.cloudfunctions.net'
            '/submitSuggestion',
      );
      expect(capturedHeaders!['authorization'], 'Bearer test-token');
      expect(capturedHeaders!['content-type'], 'application/json');

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(data['type'], 'general');
      expect(data['text'], 'Great app!');
      expect(data['cityId'], 'htx');
    });

    test('omits cityId from payload when null', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'tok');

      String? capturedBody;
      final client = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(jsonEncode({'result': null}), 200);
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore, auth: mockAuth, httpClient: client);
      await repo.submit(type: 'general', text: 'Hello');

      final data =
          (jsonDecode(capturedBody!) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(data.containsKey('cityId'), isFalse);
    });

    test('throws PermissionDenied when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final client = http_testing.MockClient((_) async {
        fail('Should not make HTTP request');
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore, auth: mockAuth, httpClient: client);

      expect(
        () => repo.submit(type: 'general', text: 'Test'),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('throws RateLimited on RESOURCE_EXHAUSTED error', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'tok');

      final client = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'status': 'RESOURCE_EXHAUSTED',
              'message': 'Daily limit reached.',
            },
          }),
          429,
        );
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore, auth: mockAuth, httpClient: client);

      expect(
        () => repo.submit(type: 'general', text: 'Too many'),
        throwsA(isA<RateLimited>()),
      );
    });

    test('throws PermissionDenied on UNAUTHENTICATED error', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'expired');

      final client = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {
              'status': 'UNAUTHENTICATED',
              'message': 'Token expired.',
            },
          }),
          401,
        );
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore, auth: mockAuth, httpClient: client);

      expect(
        () => repo.submit(type: 'general', text: 'Expired token'),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('throws FirestoreWriteException on unknown server error', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'tok');

      final client = http_testing.MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = SuggestionRepository(
        firestore: fakeFirestore, auth: mockAuth, httpClient: client);

      expect(
        () => repo.submit(type: 'general', text: 'Boom'),
        throwsA(isA<FirestoreWriteException>()),
      );
    });
  });
}
