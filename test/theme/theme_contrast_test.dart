import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/theme/theme_variants.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(int r, int g, int b) {
  double c(int v) {
    final s = v / 255.0;
    return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b);
}

double _contrastRatio(int fgValue, int bgValue) {
  final fg = _luminance((fgValue >> 16) & 0xFF, (fgValue >> 8) & 0xFF, fgValue & 0xFF);
  final bg = _luminance((bgValue >> 16) & 0xFF, (bgValue >> 8) & 0xFF, bgValue & 0xFF);
  final lighter = fg > bg ? fg : bg;
  final darker = fg > bg ? bg : fg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA contrast', () {
    // AA requires 4.5:1 for normal text, 3:1 for large text.
    // We check 4.5:1 (the stricter bar).
    const minRatio = 4.5;

    test('editorialDark textPrimary on background passes AA', () {
      final palette = ThemePalettes.editorialDark;
      final ratio = _contrastRatio(
        palette.textPrimary.value & 0xFFFFFF,
        palette.background.value & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(minRatio));
    });

    test('instagramDark textPrimary on background passes AA', () {
      final palette = ThemePalettes.instagramDark;
      final ratio = _contrastRatio(
        palette.textPrimary.value & 0xFFFFFF,
        palette.background.value & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(minRatio));
    });

    test('editorialDark textSecondary on background passes AA', () {
      final palette = ThemePalettes.editorialDark;
      final ratio = _contrastRatio(
        palette.textSecondary.value & 0xFFFFFF,
        palette.background.value & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(minRatio));
    });

    test('editorialDark textPrimary is not pure white', () {
      final palette = ThemePalettes.editorialDark;
      expect(palette.textPrimary.value & 0xFFFFFF, isNot(equals(0xFFFFFF)));
    });

    test('instagramDark textPrimary is not pure white', () {
      final palette = ThemePalettes.instagramDark;
      expect(palette.textPrimary.value & 0xFFFFFF, isNot(equals(0xFFFFFF)));
    });
  });
}
