import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/core/network/app_check_header.dart';

/// The deployed Cloud Functions region.
const String _kFunctionsRegion = 'us-central1';

/// The Firebase project ID.
const String _kProjectId = 'majorcitymusteats';

/// Asks the server to re-read this user's entitlements from
/// RevenueCat and repair the membership claim from the answer.
///
/// Why this exists. The RevenueCat webhook is the only thing that has
/// ever set a membership claim, so a webhook that is never delivered
/// leaves a paying user locked out permanently.
/// `MembershipProvider.refreshEntitlements` detects that state
/// exactly, since the device can see the entitlement while the claim
/// says free, and before this the only remedy on offer was a retry
/// button that re-read the same claim that was never going to change.
///
/// The user is identified by the ID token, never by a field in the
/// payload. A client that could name the user could ask for somebody
/// else's tier to be recomputed.
class MembershipRepository {
  MembershipRepository({
    FirebaseAuth? auth,
    http.Client? httpClient,
    AppCheckTokenProvider? appCheckToken,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _appCheckToken = appCheckToken ?? defaultAppCheckToken;

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final AppCheckTokenProvider _appCheckToken;

  /// Reconciles the signed-in user's tier against RevenueCat.
  ///
  /// Returns the tier the server now holds, as its claim string
  /// (`free`, `localsPass`, `cityInsider`).
  ///
  /// Throws [RateLimited] once the daily cap is spent, and
  /// [FirestoreWriteException] if the server could not reach
  /// RevenueCat. That distinction is deliberate: "we could not check"
  /// is not "you have nothing", and the caller must not treat the
  /// second as the first.
  Future<String> reconcile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PermissionDenied(
        'You need to sign in to refresh your membership.',
      );
    }

    final idToken = await user.getIdToken();
    final url = Uri.parse(
      'https://$_kFunctionsRegion-$_kProjectId.cloudfunctions.net'
      '/reconcileMembership',
    );
    final headers = await callableHeaders(
      idToken: idToken,
      appCheckToken: _appCheckToken,
    );

    final http.Response response;
    try {
      response = await _httpClient.post(
        url,
        headers: headers,
        body: jsonEncode({'data': <String, dynamic>{}}),
      );
    } on Exception {
      throw const FirestoreWriteException();
    }

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = body['result'] as Map<String, dynamic>?;
        final tier = result?['tier'] as String?;
        if (tier != null) return tier;
      } on Exception {
        // Fall through: a 200 whose body cannot be read is a failure
        // to learn anything, not a report that the user is free.
      }
      throw const FirestoreWriteException();
    }

    _handleErrorResponse(response);
  }

  Never _handleErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      final status = error?['status'] as String? ?? '';

      if (status == 'RESOURCE_EXHAUSTED') {
        throw const RateLimited();
      }
      if (status == 'UNAUTHENTICATED') {
        throw const PermissionDenied(
          'You need to sign in to refresh your membership.',
        );
      }
    } on AppException {
      rethrow;
    } on Exception {
      // JSON parse failure, fall through to the generic error.
    }
    throw const FirestoreWriteException();
  }
}
