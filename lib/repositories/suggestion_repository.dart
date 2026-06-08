import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/suggestion.dart';

/// Repository for submitting and tracking user suggestions.
///
/// Suggestions are submitted via Cloud Function for tamper-proof
/// server-side rate limiting. The server controls the date key
/// so a client-supplied backdated key cannot dodge the daily cap.
class SuggestionRepository {
  SuggestionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Submits a new suggestion via the `submitSuggestion` Cloud Function.
  ///
  /// The function enforces the daily cap server-side using server time.
  /// Throws [RateLimited] if the user has hit [kDailySuggestionCap].
  Future<void> submit({
    required String type,
    required String text,
    String? cityId,
  }) async {
    try {
      await _functions.httpsCallable('submitSuggestion').call<dynamic>({
        'type': type,
        'text': text,
        if (cityId != null) 'cityId': cityId,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw const RateLimited();
      }
      if (e.code == 'unauthenticated') {
        throw const PermissionDenied(
          'You need to sign in to submit a suggestion.',
        );
      }
      throw const FirestoreWriteException();
    }
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
