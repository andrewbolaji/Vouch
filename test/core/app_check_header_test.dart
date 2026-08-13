import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/core/network/app_check_header.dart';

/// Finding 14. Both callables are hand-rolled HTTPS POSTs, because
/// `cloud_functions` is not in pubspec.yaml, so nothing was attaching
/// an App Check token. Enforcing either callable would have broken
/// commenting and suggestions for every user.
void main() {
  group('callableHeaders', () {
    test('attaches the App Check token when one is available', () async {
      final headers = await callableHeaders(
        idToken: 'id-123',
        appCheckToken: () async => 'ac-abc',
      );

      expect(headers[kAppCheckHeader], 'ac-abc');
      expect(headers[HttpHeaders.authorizationHeader], 'Bearer id-123');
      expect(headers[HttpHeaders.contentTypeHeader], 'application/json');
    });

    test('omits the header entirely when no token is available', () async {
      // Sending the header with an empty or null value is worse than
      // omitting it: an enforcing backend reads a present-but-invalid
      // token as an attestation failure rather than as an unattested
      // request, and the two produce different diagnostics.
      final headers = await callableHeaders(
        idToken: 'id-123',
        appCheckToken: () async => null,
      );

      expect(headers.containsKey(kAppCheckHeader), isFalse);
      expect(headers[HttpHeaders.authorizationHeader], 'Bearer id-123');
    });

    test('omits the header when the token is an empty string', () async {
      final headers = await callableHeaders(
        idToken: 'id-123',
        appCheckToken: () async => '',
      );

      expect(headers.containsKey(kAppCheckHeader), isFalse);
    });

    test('the token is fetched on every call, never cached', () async {
      // The SDK caches and refreshes internally, so calling per
      // request is cheap and always yields a currently valid token. A
      // cache of our own would pass every test here and work for the
      // first hour in production, then start failing at expiry.
      var calls = 0;
      Future<String?> provider() async {
        calls++;
        return 'ac-$calls';
      }

      final first = await callableHeaders(
        idToken: 'id',
        appCheckToken: provider,
      );
      final second = await callableHeaders(
        idToken: 'id',
        appCheckToken: provider,
      );

      expect(calls, 2);
      expect(first[kAppCheckHeader], 'ac-1');
      expect(second[kAppCheckHeader], 'ac-2');
    });

    test('preserves the existing null idToken behaviour', () async {
      // getIdToken() returns String?, and the inline code this
      // replaced interpolated it directly. Preserved deliberately so
      // this change does not alter auth behaviour as a side effect.
      final headers = await callableHeaders(
        idToken: null,
        appCheckToken: () async => 'ac-abc',
      );

      expect(headers[HttpHeaders.authorizationHeader], 'Bearer null');
    });
  });
}
