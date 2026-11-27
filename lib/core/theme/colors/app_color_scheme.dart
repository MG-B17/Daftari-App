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
    required this.customersAccentSurface,
    required this.whatsappColor,
    required this.onWhatsappColor,
    required this.creditSurface,
    required this.paymentSurface,
    required this.lockAccentSurface,
    required this.lockKeySurface,
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
    customersAccentSurface: AppColors.customersAccentSurface,
    whatsappColor: AppColors.whatsapp,
    onWhatsappColor: AppColors.text,
    creditSurface: AppColors.creditSurface,
    paymentSurface: AppColors.paymentSurface,
    lockAccentSurface: AppColors.primarySurface,
    lockKeySurface: AppColors.surface,
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
    customersAccentSurface: AppColors.customersDarkAccentSurface,
    whatsappColor: AppColors.whatsapp,
    onWhatsappColor: AppColors.text,
    creditSurface: Color.lerp(AppColors.darkSurface, AppColors.credit, .2)!,
    paymentSurface: Color.lerp(AppColors.darkSurface, AppColors.payment, .2)!,
    lockAccentSurface: Color.lerp(
      AppColors.darkSurface,
      AppColors.primary,
      .2,
    )!,
    lockKeySurface: AppColors.darkSurface,
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
  final Color customersAccentSurface;
  final Color whatsappColor;
  final Color onWhatsappColor;
  final Color creditSurface;
  final Color paymentSurface;

  final Color lockAccentSurface;
  final Color lockKeySurface;
  Color get lockActiveDot => brand;
  Color get lockDeleteSurface => creditSurface;
  Color get lockDeleteForeground => creditColor;

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
    Color? customersAccentSurface,
    Color? whatsappColor,
    Color? onWhatsappColor,
    Color? creditSurface,
    Color? paymentSurface,
    Color? lockAccentSurface,
    Color? lockKeySurface,
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
    customersAccentSurface:
        customersAccentSurface ?? this.customersAccentSurface,
    whatsappColor: whatsappColor ?? this.whatsappColor,
    onWhatsappColor: onWhatsappColor ?? this.onWhatsappColor,
    creditSurface: creditSurface ?? this.creditSurface,
    paymentSurface: paymentSurface ?? this.paymentSurface,
    lockAccentSurface: lockAccentSurface ?? this.lockAccentSurface,
    lockKeySurface: lockKeySurface ?? this.lockKeySurface,
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
      whatsappColor: Color.lerp(whatsappColor, other.whatsappColor, t)!,
      onWhatsappColor: Color.lerp(onWhatsappColor, other.onWhatsappColor, t)!,
      creditSurface: Color.lerp(creditSurface, other.creditSurface, t)!,
      paymentSurface: Color.lerp(paymentSurface, other.paymentSurface, t)!,
      lockAccentSurface: Color.lerp(
        lockAccentSurface,
        other.lockAccentSurface,
        t,
      )!,
      lockKeySurface: Color.lerp(lockKeySurface, other.lockKeySurface, t)!,
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
      customersAccentSurface: Color.lerp(
        customersAccentSurface,
        other.customersAccentSurface,
        t,
      )!,
    );
  }
}
