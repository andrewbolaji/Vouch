import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/user_profile.dart';

/// Repository for user profile operations in Firestore.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Returns the user profile for the given UID, or null if it does not exist.
  Future<UserProfile?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return UserProfile.fromJson(data);
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Creates (or overwrites) a user profile document.
  Future<void> createUser(UserProfile profile) async {
    try {
      await _usersRef.doc(profile.id).set(profile.toJson());
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Adds or removes a restaurant ID from the user's saved list.
  Future<void> updateSaved(
    String uid,
    String restaurantId, {
    required bool add,
  }) async {
    try {
      await _usersRef.doc(uid).update({
        'savedRestaurantIds': add
            ? FieldValue.arrayUnion([restaurantId])
            : FieldValue.arrayRemove([restaurantId]),
      });
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Bumps the user's lastActiveAt timestamp.
  Future<void> updateLastActive(String uid) async {
    try {
      await _usersRef.doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns the list of saved restaurant IDs for the given user.
  Future<List<String>> getSavedIds(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final raw = data['savedRestaurantIds'] as List<dynamic>? ?? [];
      return raw.cast<String>();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }
}
