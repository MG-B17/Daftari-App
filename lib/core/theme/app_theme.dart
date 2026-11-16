import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_color_scheme.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
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
