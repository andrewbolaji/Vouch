import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vouch/models/timestamp_converter.dart';

part 'report.freezed.dart';
part 'report.g.dart';

/// Reasons a user can report a comment.
enum ReportReason { spam, harassment, inappropriate, other }

/// Daily cap on reports per user. Enforced client-side and in security rules.
const int kDailyReportCap = 5;

@freezed
abstract class Report with _$Report {
  const factory Report({
    required String id,
    required String reporterUid,
    required String commentId,
    required String commentPath,
    required String restaurantId,
    required String cityId,
    required ReportReason reason,
    @TimestampConverter() required DateTime createdAt,
  }) = _Report;

  factory Report.fromJson(Map<String, dynamic> json) =>
      _$ReportFromJson(json);
}
