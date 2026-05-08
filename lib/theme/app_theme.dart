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

  /// The contrasting color for use on accent-colored surfaces
  /// (buttons, badges).
  /// Dark themes get black text on accent; light themes get white.
  static Color get onAccent =>
      brightness == Brightness.dark ? Colors.black : Colors.white;

  /// Standard accent button style used across upgrade, onboarding,
  /// sign-in, etc.
  static ButtonStyle get accentButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: onAccent,
    disabledBackgroundColor: surfaceVariant,
    padding: const EdgeInsets.symmetric(vertical: spacingMd),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    ),
  );

  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // Typography
  static bool get _useSerif =>
      kActiveTheme == AppThemeVariant.editorialDark ||
      kActiveTheme == AppThemeVariant.editorialLight;

  static TextStyle get displayLarge => _useSerif
      ? GoogleFonts.dmSerifDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        )
      : GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        );

  static TextStyle get displayMedium => _useSerif
      ? GoogleFonts.dmSerifDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        )
      : GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        );

  static TextStyle get headlineLarge => _useSerif
      ? GoogleFonts.dmSerifDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        )
      : GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        );

  static TextStyle get headlineMedium => _useSerif
      ? GoogleFonts.dmSerifDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        )
      : GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        );

  static TextStyle get accentItalic => _useSerif
      ? GoogleFonts.dmSerifDisplay(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: accent,
        )
      : GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: accent,
        );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  // ThemeData
  static ThemeData get themeData => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      secondary: accentMuted,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      error: error,
      onError: Colors.white,
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
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textTertiary,
    ),
    iconTheme: IconThemeData(color: textSecondary),
  );
}
