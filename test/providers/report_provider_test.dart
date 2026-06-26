
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vouch/core/error/app_exception.dart';
import 'package:vouch/models/report.dart';
import 'package:vouch/providers/report_provider.dart';
import 'package:vouch/repositories/report_repository.dart';
import 'package:vouch/services/auth_service.dart';

// -- Fakes --

const _userA = AuthUser(
  uid: 'user-a',
  email: 'a@test.com',
  method: AuthMethod.email,
);

class FakeReportRepository implements ReportRepository {
  int submitCallCount = 0;
  AppException? submitThrow;
  final Map<String, int> _counts = {};

  void seedCount(String uid, int count) => _counts[uid] = count;

  @override
  Future<void> submit({
    required String reporterUid,
    required String commentId,
    required String commentPath,
    required String restaurantId,
    required String cityId,
    required ReportReason reason,
  }) async {
    submitCallCount++;
    if (submitThrow != null) throw submitThrow!;
  }

  @override
  Future<int> getRemainingToday(String uid) async {
    if (_counts.containsKey(uid)) {
      return kDailyReportCap - _counts[uid]!;
    }
    return kDailyReportCap;
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AuthService auth;
  late FakeReportRepository repo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    auth = AuthService.mock();
    repo = FakeReportRepository();
  });

  group('ReportProvider', () {
    test('signed-out user sees full remaining count', () async {
      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );
      await _settle();

      expect(provider.remainingToday, kDailyReportCap);
      expect(provider.canReport, isTrue);

      provider.dispose();
    });

    test('submit calls repo and decrements counter', () async {
      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      await provider.submitReport(
        commentId: 'c1',
        commentPath: 'restaurants/hou-1/comments/c1',
        restaurantId: 'hou-1',
        cityId: 'houston',
        reason: ReportReason.spam,
      );

      expect(repo.submitCallCount, 1);
      expect(provider.remainingToday, kDailyReportCap - 1);
      expect(provider.isSubmitting, isFalse);

      provider.dispose();
    });

    test('submit while signed out throws PermissionDenied', () async {
      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );
      await _settle();

      expect(
        () => provider.submitReport(
          commentId: 'c1',
          commentPath: 'restaurants/hou-1/comments/c1',
          restaurantId: 'hou-1',
          cityId: 'houston',
          reason: ReportReason.harassment,
        ),
        throwsA(isA<PermissionDenied>()),
      );

      provider.dispose();
    });

    test('RateLimited from server resets counter to 0', () async {
      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      repo.submitThrow = const RateLimited();

      await expectLater(
        provider.submitReport(
          commentId: 'c1',
          commentPath: 'restaurants/hou-1/comments/c1',
          restaurantId: 'hou-1',
          cityId: 'houston',
          reason: ReportReason.inappropriate,
        ),
        throwsA(isA<RateLimited>()),
      );

      expect(provider.remainingToday, 0);
      expect(provider.canReport, isFalse);

      provider.dispose();
    });

    test('loads remaining from server on sign-in', () async {
      repo.seedCount('user-a', 3); // 3 used, 2 remaining

      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.remainingToday, 2);

      provider.dispose();
    });

    test('dispose removes auth listener', () async {
      final provider = ReportProvider(
        authService: auth,
        reportRepository: repo,
      );
      await _settle();

      provider.dispose();

      auth.setMockUser(_userA);
      await _settle();

      expect(provider.remainingToday, kDailyReportCap);
    });
  });
}
