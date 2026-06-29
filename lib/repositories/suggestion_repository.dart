import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/suggestion.dart';

/// The deployed Cloud Functions region.
const String _kFunctionsRegion = 'us-central1';

/// The Firebase project ID.
const String _kProjectId = 'majorcitymusteats';

/// Repository for submitting and tracking user suggestions.
///
/// Suggestions are submitted via a plain HTTPS POST to the deployed
/// Cloud Function for tamper-proof server-side rate limiting.
class SuggestionRepository {
  SuggestionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;

  /// Submits a new suggestion via HTTPS POST to the `submitSuggestion`
  /// Cloud Function.
  ///
  /// The function enforces the daily cap server-side using server time.
  /// Throws [RateLimited] if the user has hit [kDailySuggestionCap].
  Future<void> submit({
    required String type,
    required String text,
    String? cityId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PermissionDenied(
        'You need to sign in to submit a suggestion.',
      );
    }

    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://$_kFunctionsRegion-$_kProjectId.cloudfunctions.net'
      '/submitSuggestion',
    );

    final payload = <String, dynamic>{
      'type': type,
      'text': text,
      'cityId': ?cityId,
    };

    final http.Response response;
    try {
      response = await _httpClient.post(
        url,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $idToken',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({'data': payload}),
      );
    } on Exception {
      throw const FirestoreWriteException();
    }

    if (response.statusCode == 200) return;

    // The callable protocol returns errors as JSON with a
    // {"error": {"status": "...", "message": "..."}} envelope.
    _handleErrorResponse(response);
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      final status = error?['status'] as String? ?? '';

      if (status == 'RESOURCE_EXHAUSTED') {
        throw const RateLimited();
      }
      if (status == 'UNAUTHENTICATED') {
        throw const PermissionDenied(
          'You need to sign in to submit a suggestion.',
        );
      }
    } on AppException {
      rethrow;
    } on Exception {
      // JSON parse failure -- fall through to generic error.
    }
    throw const FirestoreWriteException();
  }

  /// Returns the number of suggestions the user can still submit today.
  ///
  /// Reads from the user's suggestionCounts subcollection.
  Future<int> getRemainingToday(String userId) async {
    try {
      final today = _todayKey();
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('suggestionCounts')
          .doc(today)
          .get();
      if (!doc.exists) return kDailySuggestionCap;
      final count = (doc.data()?['count'] as int?) ?? 0;
      final remaining = kDailySuggestionCap - count;
      return remaining < 0 ? 0 : remaining;
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }
}
