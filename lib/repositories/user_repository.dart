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

  /// Ensures a user doc exists with all required fields.
  /// Uses set-with-merge so it creates the doc if missing and
  /// does not overwrite existing list fields on re-sign-in.
  Future<void> ensureUserDoc({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (doc.exists) {
        // Doc exists; update displayName/email but do not
        // clobber lists, tier, or timestamps.
        await _usersRef.doc(uid).set({
          'displayName': displayName,
          'email': email,
        }, SetOptions(merge: true));
      } else {
        // First sign-in: write a complete initial doc.
        await _usersRef.doc(uid).set({
          'id': uid,
          'displayName': displayName,
          'email': email,
          'membershipTier': 'free',
          'savedRestaurantIds': <String>[],
          'blockedUserIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

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

  /// Adds a user ID to the blocker's blockedUserIds list.
  /// Uses set-with-merge so the write succeeds even if the
  /// user doc does not exist yet.
  Future<void> addBlock(String blockerUid, String blockedUid) async {
    try {
      await _usersRef.doc(blockerUid).set({
        'blockedUserIds': FieldValue.arrayUnion([blockedUid]),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Removes a user ID from the blocker's blockedUserIds list.
  /// Uses set-with-merge so the write succeeds even if the
  /// user doc does not exist yet.
  Future<void> removeBlock(String blockerUid, String blockedUid) async {
    try {
      await _usersRef.doc(blockerUid).set({
        'blockedUserIds': FieldValue.arrayRemove([blockedUid]),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns the list of blocked user IDs for the given user.
  Future<List<String>> getBlockedIds(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final raw = data['blockedUserIds'] as List<dynamic>? ?? [];
      return raw.cast<String>();
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
