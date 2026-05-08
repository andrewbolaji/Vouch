import 'package:flutter/material.dart';

enum AppThemeVariant { editorialDark, instagramDark, editorialLight }

const AppThemeVariant kActiveTheme = AppThemeVariant.instagramDark;

class ThemeColors {

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.accent,
    required this.accentMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.error,
    required this.cardBackground,
    required this.primaryMuted,
    required this.brightness,
  });
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color accent;
  final Color accentMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color error;
  final Color cardBackground;
  final Color primaryMuted;
  final Brightness brightness;
}

class ThemePalettes {
  ThemePalettes._();

  static const editorialDark = ThemeColors(
    background: Color(0xFF141110),
    surface: Color(0xFF1C1917),
    surfaceVariant: Color(0xFF262220),
    accent: Color(0xFFE89B5C),
    accentMuted: Color(0xFFB87A45),
    textPrimary: Color(0xFFF5F0EB),
    textSecondary: Color(0xFFB8AFA6),
    textTertiary: Color(0xFF7A7269),
    divider: Color(0xFF2E2A27),
    error: Color(0xFFCF6679),
    cardBackground: Color(0xFF1C1917),
    primaryMuted: Color(0xFF3D3530),
    brightness: Brightness.dark,
  );

  static const instagramDark = ThemeColors(
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceVariant: Color(0xFF1E1E1E),
    accent: Color(0xFFE1306C),
    accentMuted: Color(0xFFB8264F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF6B6B6B),
    divider: Color(0xFF2A2A2A),
    error: Color(0xFFED4956),
    cardBackground: Color(0xFF121212),
    primaryMuted: Color(0xFF2A2A2A),
    brightness: Brightness.dark,
  );

  static const editorialLight = ThemeColors(
    background: Color(0xFFF8F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0EBE4),
    accent: Color(0xFFD4854A),
    accentMuted: Color(0xFFB87A45),
    textPrimary: Color(0xFF1A1613),
    textSecondary: Color(0xFF5C5550),
    textTertiary: Color(0xFF8A847E),
    divider: Color(0xFFE8E2DA),
    error: Color(0xFFB00020),
    cardBackground: Color(0xFFFFFFFF),
    primaryMuted: Color(0xFFE8E2DA),
    brightness: Brightness.light,
  );

  static ThemeColors forVariant(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.editorialDark:
        return editorialDark;
      case AppThemeVariant.instagramDark:
        return instagramDark;
      case AppThemeVariant.editorialLight:
        return editorialLight;
    }
  }
}
