import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/city.dart';

/// Repository for reading city data from Firestore.
class CityRepository {
  CityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _citiesRef =>
      _firestore.collection('cities');

  /// Returns all cities ordered alphabetically by name.
  Future<List<City>> getCities() async {
    try {
      final snapshot = await _citiesRef.orderBy('name').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return City.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns a single city by its document ID, or null if not found.
  Future<City?> getById(String id) async {
    try {
      final doc = await _citiesRef.doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return City.fromJson(data);
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }
}
