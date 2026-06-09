import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/models/report.dart';

void main() {
  group('Report model', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 'report-1',
        'reporterUid': 'user-a',
        'commentId': 'c1',
        'commentPath': 'restaurants/hou-1/comments/c1',
        'restaurantId': 'hou-1',
        'cityId': 'houston',
        'reason': 'spam',
        'createdAt': DateTime(2026, 6, 9).toIso8601String(),
      };

      final report = Report.fromJson(json);

      expect(report.reporterUid, 'user-a');
      expect(report.commentId, 'c1');
      expect(report.commentPath, 'restaurants/hou-1/comments/c1');
      expect(report.restaurantId, 'hou-1');
      expect(report.cityId, 'houston');
      expect(report.reason, ReportReason.spam);
    });

    test('round-trip: toJson then fromJson preserves all fields', () {
      final original = Report(
        id: 'report-1',
        reporterUid: 'user-a',
        commentId: 'c1',
        commentPath: 'restaurants/hou-1/comments/c1',
        restaurantId: 'hou-1',
        cityId: 'houston',
        reason: ReportReason.harassment,
        createdAt: DateTime(2026, 6, 9),
      );

      final json = original.toJson();
      final restored = Report.fromJson(json);

      expect(restored, equals(original));
    });

    test('all ReportReason values round-trip', () {
      for (final reason in ReportReason.values) {
        final report = Report(
          id: 'test',
          reporterUid: 'uid',
          commentId: 'c',
          commentPath: 'path',
          restaurantId: 'r',
          cityId: 'city',
          reason: reason,
          createdAt: DateTime(2026),
        );
        final restored = Report.fromJson(report.toJson());
        expect(restored.reason, reason);
      }
    });
  });
}
