import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/spacing/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void configure(Size size) => ScreenUtil.configure(
    data: MediaQueryData(size: size),
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
  );

  test('intro tokens match design-space dimensions at reference size', () {
    configure(AppConstants.designSize);
    expect(
      AppSpacing.introPagePadding,
      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    );
    expect(AppSpacing.onboardingCardWidth, 280);
    expect(AppSpacing.onboardingCardHeight, 240);
    expect(AppSpacing.splashLogoSize, 112);
    expect(AppSpacing.introNextButtonPadding.top, 64);
  });

  test(
    'intro sizing scales down and compact-height footer preserves space',
    () {
      configure(const Size(320, 599));
      expect(AppSpacing.hasCompactHeight, isTrue);
      expect(AppSpacing.introNextButtonPadding.top, AppSpacing.md);
      expect(AppSpacing.introPagePadding.horizontal, lessThan(48));
      expect(AppSpacing.splashLogoSize, lessThan(112));
      expect(AppSpacing.onboardingCardWidth, 240);
      expect(AppSpacing.onboardingCardHeight, 240);
      expect(AppSpacing.badgeShadow.blurRadius, AppSpacing.xs);
      expect(AppSpacing.badgeShadow.color, AppColors.shadow);
    },
  );

  test('large surfaces keep content and sample card bounded', () {
    configure(const Size(1440, 1280));
    expect(AppSpacing.introMaxWidth, 520);
    expect(AppSpacing.onboardingCardWidth, 360);
    expect(AppSpacing.onboardingCardHeight, 320);
    expect(AppSpacing.splashLogoSize, greaterThan(112));
    configure(const Size(390, 600));
    expect(AppSpacing.hasCompactHeight, isFalse);
    expect(AppSpacing.introNextButtonPadding.top, 64.h);
  });
}
