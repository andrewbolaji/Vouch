import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vouch/theme/theme_variants.dart';

class AppTheme {
  AppTheme._();

  static final ThemeColors _colors = ThemePalettes.forVariant(kActiveTheme);

  // Colors
  static Color get background => _colors.background;
  static Color get surface => _colors.surface;
  static Color get surfaceVariant => _colors.surfaceVariant;
  static Color get accent => _colors.accent;
  static Color get accentMuted => _colors.accentMuted;
  static Color get textPrimary => _colors.textPrimary;
  static Color get textSecondary => _colors.textSecondary;
  static Color get textTertiary => _colors.textTertiary;
  static Color get divider => _colors.divider;
  static Color get error => _colors.error;
  static Color get cardBackground => _colors.cardBackground;
  static Color get primaryMuted => _colors.primaryMuted;
  static Brightness get brightness => _colors.brightness;

  // Block Party extended tokens (fall back to accent/error for older variants)
  static Color get goldInk => _colors.goldInk ?? accent;
  static Color get success => _colors.success ?? const Color(0xFF2E7D46);
  static Color get warning => _colors.warning ?? accent;
  static Color get borderColor => _colors.borderColor ?? divider;
  static Color get lineSoft => _colors.lineSoft ?? divider;

  // Ink scrim for text over photos (always ink-based, never background)
  static Color get inkScrim => textPrimary;

  /// Text color for use on accent-colored surfaces (buttons, badges).
  static Color get onAccent {
    if (kActiveTheme == AppThemeVariant.blockParty) return textPrimary;
    return brightness == Brightness.dark ? background : Colors.white;
  }

  /// Text color for use on goldInk surfaces.
  static Color get onGoldInk => background;

  /// Standard accent button style: flame fill, ink border, hard shadow.
  static ButtonStyle get accentButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: onAccent,
    disabledBackgroundColor: surfaceVariant,
    padding: const EdgeInsets.symmetric(vertical: spacingMd),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      side: BorderSide(color: borderColor, width: borderInkWidth),
    ),
  );

  /// Secondary button style: paper-raised fill, ink border, no shadow.
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: surface,
    foregroundColor: textPrimary,
    disabledBackgroundColor: surfaceVariant,
    padding: const EdgeInsets.symmetric(vertical: spacingMd),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      side: BorderSide(color: borderColor, width: borderInkWidth),
    ),
  );

  // Spacing (4-based scale per Block Party doc)
  static const double spacingXxs = 2;
  static const double spacingXs = 4;
  static const double spacingXsSm = 6;
  static const double spacingSm = 8;
  static const double spacingMdSm = 12;
  static const double spacingMd = 16;
  static const double spacingMdLg = 20;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXlLg = 40;
  static const double spacingXxl = 48;

  // Radii (hard edges are the Block Party signature)
  static const double radiusSm = 4;
  static const double radiusMd = 4;
  static const double radiusLg = 4;
  static const double radiusXl = 4;
  static const double radiusPill = 999;

  // Borders
  static const double borderInkWidth = 2;
  static const double borderHairlineWidth = 1;

  static BorderSide get borderInk =>
      BorderSide(color: borderColor, width: borderInkWidth);
  static BorderSide get borderHairline =>
      BorderSide(color: lineSoft);

  // Shadows (hard offset, no blur, screenprint sticker feel)
  static List<BoxShadow> get shadowHard => [
    BoxShadow(
      color: borderColor,
      offset: const Offset(4, 4),
    ),
  ];

  static List<BoxShadow> get shadowPressed => [
    BoxShadow(
      color: borderColor,
      offset: const Offset(2, 2),
    ),
  ];

  // Alpha values
  static const double alphaWatermark = 0.07;
  static const double alphaAccentSubtle = 0.12;

  // Sizes
  static const double watermarkFontSize = 80;

  // ---------------------------------------------------------------------------
  // Typography: Anton for poster/rank moments, Archivo for everything else
  // ---------------------------------------------------------------------------

  static bool get _useBlockParty =>
      kActiveTheme == AppThemeVariant.blockParty;

  static bool get _useSerif =>
      !_useBlockParty &&
      (kActiveTheme == AppThemeVariant.editorialDark ||
       kActiveTheme == AppThemeVariant.editorialLight);

  // Display XL (Anton 40-48): city names, hero rank
  static TextStyle get displayLarge {
    if (_useBlockParty) {
      return GoogleFonts.anton(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.1,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 32, fontWeight: FontWeight.w400, color: textPrimary)
        : GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary);
  }

  // Display L (Anton 28-34)
  static TextStyle get displayMedium {
    if (_useBlockParty) {
      return GoogleFonts.anton(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.15,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 24, fontWeight: FontWeight.w400, color: textPrimary)
        : GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary);
  }

  // Title H1 (Archivo 800 26-30)
  static TextStyle get headlineLarge {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.2,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 20, fontWeight: FontWeight.w400, color: textPrimary)
        : GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary);
  }

  // Section H2 / restaurant name (Archivo 700 16-18)
  static TextStyle get headlineMedium {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.25,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 18, fontWeight: FontWeight.w400, color: textPrimary)
        : GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary);
  }

  // Accent italic (used for Insider Notes header, etc.)
  static TextStyle get accentItalic {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: accent,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 18, fontStyle: FontStyle.italic, color: accent)
        : GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: accent);
  }

  // Body (Archivo 400-500 15-16)
  static TextStyle get bodyLarge {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      );
    }
    return GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary);
  }

  // Body medium (Archivo 400 14-15, secondary color)
  static TextStyle get bodyMedium {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.45,
      );
    }
    return GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary);
  }

  // Caption (Archivo 500 11-12, tertiary color)
  static TextStyle get bodySmall {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textTertiary,
      );
    }
    return GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary);
  }

  // Restaurant name (Archivo 800 16-18)
  static TextStyle get labelLarge {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      );
    }
    return GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary);
  }

  // Meta and label (Archivo 600 12.5-13.5)
  static TextStyle get labelMedium {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      );
    }
    return GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary);
  }

  // Button text (Archivo 700-800)
  static TextStyle get buttonText {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.3,
      );
    }
    return GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.5);
  }

  // Rank chip numeral (Anton 18-22)
  static TextStyle get rankDisplay {
    if (_useBlockParty) {
      return GoogleFonts.anton(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );
    }
    return _useSerif
        ? GoogleFonts.dmSerifDisplay(
            fontSize: 20, fontWeight: FontWeight.w400, color: textPrimary)
        : GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary);
  }

  // Vote and stat (Archivo 800 13-14)
  static TextStyle get voteStat {
    if (_useBlockParty) {
      return GoogleFonts.archivo(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      );
    }
    return GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary);
  }

  // ---------------------------------------------------------------------------
  // Card decoration helpers
  // ---------------------------------------------------------------------------

  /// Standard card decoration: paper-raised, ink border, no shadow.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(radiusSm),
    border: Border.all(color: borderColor, width: borderInkWidth),
  );

  /// Primary card decoration: adds hard offset shadow (rank 1 / cosign only).
  static BoxDecoration get cardDecorationPrimary => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(radiusSm),
    border: Border.all(color: borderColor, width: borderInkWidth),
    boxShadow: shadowHard,
  );

  /// Image frame decoration: ink border, tight radius.
  static BoxDecoration get imageFrameDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusSm),
    border: Border.all(color: borderColor, width: borderInkWidth),
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get themeData => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accentMuted,
      onSecondary: onAccent,
      error: error,
      onError: background,
      surface: surface,
      onSurface: textPrimary,
    ),
    cardColor: cardBackground,
    dividerColor: divider,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: background,
      selectedItemColor: accent,
      unselectedItemColor: textTertiary,
    ),
    iconTheme: IconThemeData(color: textSecondary),
  );
}
