import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vouch/services/secure_storage_service.dart';

class MockFlutterSecureStorage extends Mock
    implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late SecureStorageService service;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    service = SecureStorageService(storage: mockStorage);
  });

  group('SecureStorageService', () {
    test('saveToken writes to secure storage', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.saveToken('test_token');

      verify(
        () => mockStorage.write(key: 'auth_token', value: 'test_token'),
      ).called(1);
    });

    test('readToken reads from secure storage', () async {
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'stored_token');

      final token = await service.readToken();

      expect(token, equals('stored_token'));
      verify(() => mockStorage.read(key: 'auth_token')).called(1);
    });

    test('readToken returns null when storage is empty', () async {
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      final token = await service.readToken();

      expect(token, isNull);
    });

    test('round-trip: save then read returns same value', () async {
      String? stored;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        stored = inv.namedArguments[#value] as String?;
      });
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => stored);

      await service.saveToken('round_trip_token');
      final result = await service.readToken();

      expect(result, equals('round_trip_token'));
    });

    test('saveRefreshToken writes refresh key', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.saveRefreshToken('refresh_123');

      verify(
        () => mockStorage.write(
          key: 'auth_refresh_token',
          value: 'refresh_123',
        ),
      ).called(1);
    });

    test('clearAll removes both keys', () async {
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await service.clearAll();

      verify(() => mockStorage.delete(key: 'auth_token')).called(1);
      verify(() => mockStorage.delete(key: 'auth_refresh_token')).called(1);
    });

    test('readToken handles exception gracefully', () async {
      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenThrow(Exception('storage unavailable'));

      final token = await service.readToken();

      expect(token, isNull);
    });

    test('saveToken handles exception gracefully', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('storage unavailable'));

      // Should not throw
      await service.saveToken('token');
    });
  });
}
