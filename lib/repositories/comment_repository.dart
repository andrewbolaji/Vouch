import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/comment.dart';

/// The deployed Cloud Functions region.
const String _kFunctionsRegion = 'us-central1';

/// The Firebase project ID.
const String _kProjectId = 'majorcitymusteats';

/// Repository for reading and writing comments on restaurants.
///
/// Supports cursor-based pagination. Cursors are opaque base64 strings
/// so that no DocumentSnapshot is ever leaked to callers.
///
/// Comments are created via the `submitComment` Cloud Function, not
/// a direct Firestore write: firestore.rules denies a direct create
/// outright, since the content filter has to run before anything is
/// written, not after.
class CommentRepository {
  CommentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authOverride = auth,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _authOverride;
  final http.Client _httpClient;

  // Resolved lazily, not in the constructor: FirebaseAuth.instance is
  // a platform channel call that throws with no default Firebase app
  // (e.g. a widget test that never calls Firebase.initializeApp()).
  // Eager resolution meant constructing a CommentRepository at all,
  // even one that never reads a comment, crashed outside a real
  // Firebase context. Only the code path that actually needs the
  // signed-in user's token should pay for resolving it.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

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

  /// Submits a new comment (or, if [parentId] is set, a reply) via the
  /// `submitComment` Cloud Function.
  ///
  /// The function runs the content filter server-side before writing
  /// anything, resolves userName and isInsider itself rather than
  /// trusting the client, and returns the created comment. Throws
  /// [CommentRejected] if the filter rejects the text,
  /// [DisplayNameRequired] if the user has no display name on file,
  /// [NetworkException] if the request never reached the server,
  /// [PermissionDenied] if the user is not signed in, or
  /// [FirestoreWriteException] for anything else unexpected.
  Future<Comment> submitComment({
    required String restaurantId,
    required String text,
    String? parentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PermissionDenied('You need to sign in to comment.');
    }

    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://$_kFunctionsRegion-$_kProjectId.cloudfunctions.net'
      '/submitComment',
    );

    final payload = <String, dynamic>{
      'restaurantId': restaurantId,
      'text': text,
      'parentId': ?parentId,
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
      throw const NetworkException();
    }

    if (response.statusCode != 200) {
      _handleErrorResponse(response);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = body['result'] as Map<String, dynamic>;

    return Comment(
      id: result['id'] as String,
      restaurantId: restaurantId,
      userId: user.uid,
      userName: result['userName'] as String,
      text: text,
      createdAt: DateTime.parse(result['createdAt'] as String),
      parentId: parentId,
      isInsider: result['isInsider'] as bool,
    );
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      final status = error?['status'] as String? ?? '';

      if (status == 'UNAUTHENTICATED') {
        throw const PermissionDenied('You need to sign in to comment.');
      }
      if (status == 'FAILED_PRECONDITION') {
        throw const CommentRejected();
      }
      if (status == 'ABORTED') {
        throw const DisplayNameRequired();
      }
    } on AppException {
      rethrow;
    } on Exception {
      // JSON parse failure -- fall through to generic error.
    }
    throw const FirestoreWriteException();
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
