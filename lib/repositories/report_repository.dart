import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/core/error/firestore_exception_mapper.dart';
import 'package:vouch/models/report.dart';

/// Repository for submitting comment reports to Firestore.
///
/// Reports are written to a top-level `reports` collection.
/// Rate limiting is tracked via `users/{uid}/reportCounts/{dateKey}`,
/// mirroring the suggestion-counts pattern.
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Submits a report. Increments the daily counter atomically.
  Future<void> submit({
    required String reporterUid,
    required String commentId,
    required String commentPath,
    required String restaurantId,
    required String cityId,
    required ReportReason reason,
  }) async {
    try {
      final dateKey = _todayKey();
      final counterRef = _firestore
          .collection('users')
          .doc(reporterUid)
          .collection('reportCounts')
          .doc(dateKey);

      final counterSnap = await counterRef.get();
      final currentCount =
          (counterSnap.data()?['count'] as int?) ?? 0;

      if (currentCount >= kDailyReportCap) {
        throw const RateLimited(
          'You have reached the daily report limit.'
          ' Try again tomorrow.',
        );
      }

      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'commentId': commentId,
        'commentPath': commentPath,
        'restaurantId': restaurantId,
        'cityId': cityId,
        'reason': reason.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await counterRef.set(
        {'count': FieldValue.increment(1), 'date': dateKey},
        SetOptions(merge: true),
      );
    } on RateLimited {
      rethrow;
    } on FirebaseException catch (e) {
      throw mapFirestoreException(e);
    }
  }

  /// Returns the number of reports the user can still submit today.
  Future<int> getRemainingToday(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('reportCounts')
          .doc(_todayKey())
          .get();
      if (!doc.exists) return kDailyReportCap;
      final count = (doc.data()?['count'] as int?) ?? 0;
      final remaining = kDailyReportCap - count;
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
