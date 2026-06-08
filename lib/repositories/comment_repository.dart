import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/comment.dart';

/// Repository for reading and writing comments on restaurants.
///
/// Supports cursor-based pagination. Cursors are opaque base64 strings
/// so that no DocumentSnapshot is ever leaked to callers.
class CommentRepository {
  CommentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _commentsRef(
    String restaurantId,
  ) =>
      _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('comments');

  /// Returns a page of top-level comments (parentId is null) for a restaurant,
  /// ordered by createdAt descending.
  ///
  /// [cursor] is an opaque string returned from a previous call. Pass null for
  /// the first page.
  ///
  /// Returns a record containing the comment list and a `nextCursor` that is
  /// null when there are no more pages.
  Future<({List<Comment> comments, String? nextCursor})> getPage(
    String restaurantId, {
    String? cursor,
    int pageSize = 20,
  }) async {
    try {
      var query = _commentsRef(restaurantId)
          .where('parentId', isNull: true)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (cursor != null) {
        final docPath = utf8.decode(base64Decode(cursor));
        final cursorDoc = await _firestore.doc(docPath).get();
        query = query.startAfterDocument(cursorDoc);
      }

      final snapshot = await query.get();
      final comments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['restaurantId'] = restaurantId;
        return Comment.fromJson(data);
      }).toList();

      String? nextCursor;
      if (snapshot.docs.length == pageSize) {
        final lastDoc = snapshot.docs.last;
        nextCursor = base64Encode(utf8.encode(lastDoc.reference.path));
      }

      return (comments: comments, nextCursor: nextCursor);
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns all replies to a given comment, ordered by createdAt ascending.
  Future<List<Comment>> getReplies(
    String restaurantId,
    String commentId,
  ) async {
    try {
      final snapshot = await _commentsRef(restaurantId)
          .where('parentId', isEqualTo: commentId)
          .orderBy('createdAt')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['restaurantId'] = restaurantId;
        return Comment.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Adds a new comment to the restaurant's comments subcollection.
  Future<void> add(String restaurantId, Comment comment) async {
    try {
      await _commentsRef(restaurantId).add(comment.toJson()..remove('id'));
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Deletes a comment by ID from the restaurant's comments subcollection.
  Future<void> delete(String restaurantId, String commentId) async {
    try {
      await _commentsRef(restaurantId).doc(commentId).delete();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }
}
