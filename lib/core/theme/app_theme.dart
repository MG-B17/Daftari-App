import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';
import 'app_color_scheme.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final ColorScheme _lightColorScheme = _buildColorScheme(
    Brightness.light,
  );
  static final ColorScheme _darkColorScheme = _buildColorScheme(
    Brightness.dark,
  );

  static (double, double, double)? _cachedLightMetrics;
  static ThemeData? _cachedLightTheme;
  static (double, double, double)? _cachedDarkMetrics;
  static ThemeData? _cachedDarkTheme;

  static ThemeData get light => _cached(Brightness.light);
  static ThemeData get dark => _cached(Brightness.dark);

  static ThemeData resolve(ThemeMode mode, Brightness platformBrightness) =>
      mode == ThemeMode.dark ||
          (mode == ThemeMode.system && platformBrightness == Brightness.dark)
      ? dark
      : light;

  static (double, double, double) _currentMetrics() {
    final util = ScreenUtil();
    return (util.scaleWidth, util.scaleHeight, util.scaleText);
  }

  static ThemeData _cached(Brightness brightness) {
    final metrics = _currentMetrics();
    if (brightness == Brightness.dark) {
      if (_cachedDarkTheme != null && _cachedDarkMetrics == metrics) {
        return _cachedDarkTheme!;
      }
      _cachedDarkMetrics = metrics;
      return _cachedDarkTheme = _build(Brightness.dark);
    }
    if (_cachedLightTheme != null && _cachedLightMetrics == metrics) {
      return _cachedLightTheme!;
    }
    _cachedLightMetrics = metrics;
    return _cachedLightTheme = _build(Brightness.light);
  }

  static ColorScheme _buildColorScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: dark ? AppColors.mint : AppColors.primary,
      onPrimary: dark ? AppColors.darkBackground : Colors.white,
      primaryContainer: dark ? AppColors.primary : AppColors.primarySurface,
      surface: dark ? AppColors.darkSurface : AppColors.surface,
      onSurface: dark ? AppColors.darkText : AppColors.text,
      outline: dark ? AppColors.darkBorder : AppColors.border,
      error: dark ? const Color(0xFFFFB4AB) : AppColors.credit,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = dark ? _darkColorScheme : _lightColorScheme;
    final shape = RoundedRectangleBorder(borderRadius: AppSpacing.borderRadius);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      extensions: [dark ? AppColorScheme.dark : AppColorScheme.light],
      fontFamily: AppConstants.fontFamily,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      scaffoldBackgroundColor: dark
          ? AppColors.darkBackground
          : AppColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: dark ? AppColors.darkBackground : AppColors.background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: shape.copyWith(side: BorderSide(color: colors.outline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkSurface : AppColors.input,
        contentPadding: AppSpacing.controlPadding,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadius,
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadius,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadius,
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, AppSpacing.controlHeight),
          padding: AppSpacing.controlPadding,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, AppSpacing.controlHeight),
          padding: AppSpacing.controlPadding,
          shape: shape,
          side: BorderSide(color: colors.outline),
        ),
      ),
    );
  }
}
