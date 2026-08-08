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
  ///
  /// Two independent callers can race this for the same uid (the
  /// reactive sign-in sync in SavedProvider and AuthService.
  /// updateDisplayName, on Apple sign-in in particular), so the
  /// exists-check and the write run inside a transaction: Firestore
  /// retries the whole callback if another write lands in between,
  /// instead of letting a stale "doc doesn't exist" read from one
  /// caller produce a full overwrite after the other caller already
  /// created the doc.
  ///
  /// [displayName] and [email] are only written when non-blank. A
  /// caller with nothing to contribute (an empty string, not null,
  /// is how both callers represent "no value yet") must never
  /// overwrite a real value the other caller already set, in either
  /// direction of the race. On first creation, the initial doc simply
  /// omits whichever of the two is blank rather than writing "".
  Future<void> ensureUserDoc({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final hasName = displayName.trim().isNotEmpty;
    final hasEmail = email.trim().isNotEmpty;
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _usersRef.doc(uid);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          final update = <String, dynamic>{
            if (hasName) 'displayName': displayName,
            if (hasEmail) 'email': email,
          };
          if (update.isNotEmpty) {
            // update(), not set(merge: true): the doc is confirmed to
            // exist above, and this only touches the given fields,
            // same as a merge would, without depending on a merge
            // flag transaction.set() actually respects.
            transaction.update(docRef, update);
          }
        } else {
          // First sign-in: write a complete initial doc. Not
          // merge:true here, unlike the branch above: this is a
          // genuine create, and the transaction (not a merge flag)
          // is what protects it from a concurrent creator.
          transaction.set(docRef, {
            'id': uid,
            if (hasName) 'displayName': displayName,
            if (hasEmail) 'email': email,
            'membershipTier': 'free',
            'savedRestaurantIds': <String>[],
            'blockedUserIds': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      });
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
