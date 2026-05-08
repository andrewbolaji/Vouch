import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/core/utils/format_utils.dart';

void main() {
  group('formatCount', () {
    test('returns raw number under 1000', () {
      expect(formatCount(0), '0');
      expect(formatCount(1), '1');
      expect(formatCount(999), '999');
    });

    test('formats thousands without trailing .0', () {
      expect(formatCount(1000), '1k');
      expect(formatCount(2000), '2k');
    });

    test('formats thousands with decimal', () {
      expect(formatCount(1500), '1.5k');
      expect(formatCount(2847), '2.8k');
    });

    test('formats millions without trailing .0', () {
      expect(formatCount(1000000), '1M');
    });

    test('formats millions with decimal', () {
      expect(formatCount(1500000), '1.5M');
    });
  });

  group('timeAgo', () {
    test('returns just now for recent', () {
      expect(timeAgo(DateTime.now()), 'just now');
    });

    test('returns just now for future dates (clock skew)', () {
      final future = DateTime.now().add(
        const Duration(hours: 2),
      );
      expect(timeAgo(future), 'just now');
    });

    test('returns minutes', () {
      final time = DateTime.now().subtract(
        const Duration(minutes: 5),
      );
      expect(timeAgo(time), '5m ago');
    });

    test('returns hours', () {
      final time = DateTime.now().subtract(
        const Duration(hours: 3),
      );
      expect(timeAgo(time), '3h ago');
    });

    test('returns days', () {
      final time = DateTime.now().subtract(
        const Duration(days: 7),
      );
      expect(timeAgo(time), '7d ago');
    });

    test('returns months', () {
      final time = DateTime.now().subtract(
        const Duration(days: 60),
      );
      expect(timeAgo(time), '2mo ago');
    });

    test('returns years', () {
      final time = DateTime.now().subtract(
        const Duration(days: 400),
      );
      expect(timeAgo(time), '1y ago');
    });
  });
}
