import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.brand,
    required this.paperBackground,
    required this.cardPaperSurface,
    required this.paymentColor,
    required this.creditColor,
    required this.warningColor,
    required this.onboardingGradientStart,
    required this.onboardingGradientMiddle,
    required this.onboardingGradientEnd,
  });

  static const light = AppColorScheme(
    brand: AppColors.primary,
    paperBackground: AppColors.paper,
    cardPaperSurface: AppColors.paper,
    paymentColor: AppColors.payment,
    creditColor: AppColors.credit,
    warningColor: AppColors.warning,
    onboardingGradientStart: AppColors.onboardingGradientStart,
    onboardingGradientMiddle: AppColors.surface,
    onboardingGradientEnd: AppColors.onboardingGradientEnd,
  );

  static final dark = AppColorScheme(
    brand: AppColors.primary,
    paperBackground: AppColors.darkBackground,
    cardPaperSurface: AppColors.darkSurface,
    paymentColor: AppColors.mint,
    creditColor: AppColors.creditSurface,
    warningColor: AppColors.warning,
    onboardingGradientStart: AppColors.darkBorder,
    onboardingGradientMiddle: Color.lerp(
      AppColors.darkBorder,
      AppColors.darkSurface,
      .5,
    )!,
    onboardingGradientEnd: AppColors.darkSurface,
  );

  final Color brand;
  final Color paperBackground;
  final Color cardPaperSurface;
  final Color paymentColor;
  final Color creditColor;
  final Color warningColor;
  final Color onboardingGradientStart;
  final Color onboardingGradientMiddle;
  final Color onboardingGradientEnd;

  @override
  AppColorScheme copyWith({
    Color? brand,
    Color? paperBackground,
    Color? cardPaperSurface,
    Color? paymentColor,
    Color? creditColor,
    Color? warningColor,
    Color? onboardingGradientStart,
    Color? onboardingGradientMiddle,
    Color? onboardingGradientEnd,
  }) => AppColorScheme(
    brand: brand ?? this.brand,
    paperBackground: paperBackground ?? this.paperBackground,
    cardPaperSurface: cardPaperSurface ?? this.cardPaperSurface,
    paymentColor: paymentColor ?? this.paymentColor,
    creditColor: creditColor ?? this.creditColor,
    warningColor: warningColor ?? this.warningColor,
    onboardingGradientStart:
        onboardingGradientStart ?? this.onboardingGradientStart,
    onboardingGradientMiddle:
        onboardingGradientMiddle ?? this.onboardingGradientMiddle,
    onboardingGradientEnd: onboardingGradientEnd ?? this.onboardingGradientEnd,
  );

  @override
  AppColorScheme lerp(covariant AppColorScheme? other, double t) {
    if (other == null) return this;
    return AppColorScheme(
      brand: Color.lerp(brand, other.brand, t)!,
      paperBackground: Color.lerp(paperBackground, other.paperBackground, t)!,
      cardPaperSurface: Color.lerp(
        cardPaperSurface,
        other.cardPaperSurface,
        t,
      )!,
      paymentColor: Color.lerp(paymentColor, other.paymentColor, t)!,
      creditColor: Color.lerp(creditColor, other.creditColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      onboardingGradientStart: Color.lerp(
        onboardingGradientStart,
        other.onboardingGradientStart,
        t,
      )!,
      onboardingGradientMiddle: Color.lerp(
        onboardingGradientMiddle,
        other.onboardingGradientMiddle,
        t,
      )!,
      onboardingGradientEnd: Color.lerp(
        onboardingGradientEnd,
        other.onboardingGradientEnd,
        t,
      )!,
    );
  }
}
