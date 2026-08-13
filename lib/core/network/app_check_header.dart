import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// The header Firebase reads the App Check token from.
const String kAppCheckHeader = 'X-Firebase-AppCheck';

/// Returns an App Check token, or null if one cannot be obtained.
typedef AppCheckTokenProvider = Future<String?> Function();

/// Fetches the current App Check token from the SDK.
///
/// Why this is hand-attached at all. `cloud_functions` is not in
/// `pubspec.yaml`. Both callables, `submitComment` and
/// `submitSuggestion`, are invoked as hand-rolled HTTPS POSTs, so
/// there is no Functions SDK in the request path to attach the
/// header the way it normally would be. Adopting the Functions SDK
/// properly is a real question and a separate one: the hand-rolled
/// error mapping in both repositories is load bearing, since
/// submitComment returns four distinct codes the client
/// distinguishes, including `aborted` for a missing display name.
/// See docs/FINDING_14_APP_CHECK.md.
///
/// **Fetched per request, never cached in a field here.** The SDK
/// caches and refreshes internally, so this call is cheap and always
/// returns a currently valid token. A hand-rolled cache would pass
/// every test and work for the first hour in production, then start
/// failing at expiry, which is the exact shape of bug this codebase
/// has already produced more than once.
Future<String?> defaultAppCheckToken() async {
  try {
    return await FirebaseAppCheck.instance.getToken();
  } on Exception catch (e) {
    // Never fatal. App Check is unenforced on every service today
    // (see finding 14), so a request without the header still
    // succeeds, and failing the user's comment because attestation
    // was unavailable would be a worse outcome than sending it
    // unattested. Once enforcement is on, the server rejects it and
    // the existing error handling reports that.
    debugPrint('AppCheck: token unavailable, sending unattested: $e');
    return null;
  }
}

/// Builds the headers for a callable POST, attaching the App Check
/// token when one is available.
/// [idToken] is nullable because `User.getIdToken()` is. The previous
/// inline code interpolated it directly, so a null produced the
/// literal `Bearer null` and a 401. That behaviour is preserved
/// deliberately rather than changed as a side effect of adding the
/// App Check header: it is a real latent issue, and it deserves its
/// own change with its own test.
Future<Map<String, String>> callableHeaders({
  required String? idToken,
  required AppCheckTokenProvider appCheckToken,
}) async {
  final headers = <String, String>{
    HttpHeaders.authorizationHeader: 'Bearer $idToken',
    HttpHeaders.contentTypeHeader: 'application/json',
  };
  final token = await appCheckToken();
  if (token != null && token.isNotEmpty) {
    headers[kAppCheckHeader] = token;
  }
  return headers;
}
