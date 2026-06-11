import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';

/// Repository for managing per-user votes on restaurants.
///
/// Each vote is stored as a document at
/// /restaurants/{restaurantId}/votes/{userId}.
class VoteRepository {
  VoteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _voteDoc(
    String restaurantId,
    String userId,
  ) =>
      _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('votes')
          .doc(userId);

  /// Returns true if the user has already voted for this restaurant.
  Future<bool> hasVoted(String restaurantId, String userId) async {
    try {
      final doc = await _voteDoc(restaurantId, userId).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Records a vote for the given restaurant by the given user.
  Future<void> vote(String restaurantId, String userId) async {
    try {
      await _voteDoc(restaurantId, userId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'weight': 1,
      });
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Removes a vote for the given restaurant by the given user.
  Future<void> unvote(String restaurantId, String userId) async {
    try {
      await _voteDoc(restaurantId, userId).delete();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }
}
