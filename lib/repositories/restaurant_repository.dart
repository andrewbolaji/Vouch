import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/insider_notes.dart';
import 'package:vouch/models/restaurant.dart';

/// Repository for reading restaurant data from Firestore.
class RestaurantRepository {
  RestaurantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _restaurantsRef =>
      _firestore.collection('restaurants');

  /// Returns restaurants for a given city, ordered by rank ascending.
  ///
  /// When [canViewTop10] is false the query is limited to restaurants
  /// with rank <= 5 (the free tier preview).
  Future<List<Restaurant>> getForCity(
    String cityId, {
    required bool canViewTop10,
  }) async {
    try {
      var query =
          _restaurantsRef.where('cityId', isEqualTo: cityId).orderBy('rank');

      if (!canViewTop10) {
        query = query.where('rank', isLessThanOrEqualTo: 5);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(_parseRestaurant).toList();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns a single restaurant by document ID, or null if not found.
  Future<Restaurant?> getById(String id) async {
    try {
      final doc = await _restaurantsRef.doc(id).get();
      if (!doc.exists) return null;
      return _parseRestaurant(doc);
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Reads insider notes from the subcollection
  /// /restaurants/{restaurantId}/insiderNotes/notes.
  Future<InsiderNotes?> getInsiderNotes(String restaurantId) async {
    try {
      final doc = await _restaurantsRef
          .doc(restaurantId)
          .collection('insiderNotes')
          .doc('notes')
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['restaurantId'] = restaurantId;
      return InsiderNotes.fromJson(data);
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Parses a restaurant document, stripping legacy insider fields
  /// that now live in the insiderNotes subcollection.
  Restaurant _parseRestaurant(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    data['id'] = doc.id;
    // Strip legacy insider fields; they live in the insiderNotes subcollection.
    data['insiderTip'] = null;
    data['whatToOrder'] = null;
    return Restaurant.fromJson(data);
  }
}
