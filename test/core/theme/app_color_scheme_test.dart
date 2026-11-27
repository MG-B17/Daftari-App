import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/theme/colors/app_color_scheme.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/gradients/app_gradients.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

List<Color> _values(AppColorScheme colors) => [
  colors.brand,
  colors.paperBackground,
  colors.cardPaperSurface,
  colors.paymentColor,
  colors.creditColor,
  colors.warningColor,
  colors.onboardingGradientStart,
  colors.onboardingGradientMiddle,
  colors.onboardingGradientEnd,
  colors.customersAccentSurface,
  colors.whatsappColor,
  colors.onWhatsappColor,
  colors.creditSurface,
  colors.paymentSurface,
  colors.lockAccentSurface,
  colors.lockKeySurface,
];

void main() {
  test('light and dark semantic palettes retain approved colors', () {
    expect(AppColorScheme.light.paperBackground, AppColors.paper);
    expect(AppColorScheme.dark.paperBackground, AppColors.darkBackground);
    expect(AppColorScheme.light.cardPaperSurface, AppColors.paper);
    expect(AppColorScheme.dark.cardPaperSurface, AppColors.darkSurface);
    expect(AppColorScheme.light.paymentColor, AppColors.payment);
    expect(AppColorScheme.dark.paymentColor, AppColors.mint);
    expect(AppColorScheme.light.creditColor, AppColors.credit);
    expect(AppColorScheme.dark.creditColor, AppColors.creditSurface);
    expect(AppColorScheme.light.warningColor, AppColors.warning);
    expect(AppColorScheme.dark.warningColor, AppColors.warning);
    expect(AppColorScheme.light.brand, AppColors.primary);
    expect(AppColorScheme.dark.brand, AppColors.primary);
  });

  test('copyWith preserves all fields when omitted', () {
    expect(
      _values(AppColorScheme.light.copyWith()),
      _values(AppColorScheme.light),
    );
    expect(
      _values(AppColorScheme.dark.copyWith()),
      _values(AppColorScheme.dark),
    );
  });

  test('copyWith replaces every field independently', () {
    const replacement = AppColorScheme(
      brand: AppColors.mint,
      paperBackground: AppColors.background,
      cardPaperSurface: AppColors.input,
      paymentColor: AppColors.text,
      creditColor: AppColors.darkText,
      warningColor: AppColors.border,
      onboardingGradientStart: AppColors.primarySurface,
      onboardingGradientMiddle: AppColors.creditSurface,
      onboardingGradientEnd: AppColors.paymentSurface,
      customersAccentSurface: AppColors.input,
      whatsappColor: AppColors.text,
      onWhatsappColor: AppColors.paper,
      creditSurface: AppColors.background,
      paymentSurface: AppColors.paper,
      lockAccentSurface: AppColors.input,
      lockKeySurface: AppColors.background,
    );
    final base = AppColorScheme.light;
    final copies = [
      base.copyWith(brand: replacement.brand),
      base.copyWith(paperBackground: replacement.paperBackground),
      base.copyWith(cardPaperSurface: replacement.cardPaperSurface),
      base.copyWith(paymentColor: replacement.paymentColor),
      base.copyWith(creditColor: replacement.creditColor),
      base.copyWith(warningColor: replacement.warningColor),
      base.copyWith(
        onboardingGradientStart: replacement.onboardingGradientStart,
      ),
      base.copyWith(
        onboardingGradientMiddle: replacement.onboardingGradientMiddle,
      ),
      base.copyWith(onboardingGradientEnd: replacement.onboardingGradientEnd),
      base.copyWith(customersAccentSurface: replacement.customersAccentSurface),
      base.copyWith(whatsappColor: replacement.whatsappColor),
      base.copyWith(onWhatsappColor: replacement.onWhatsappColor),
      base.copyWith(creditSurface: replacement.creditSurface),
      base.copyWith(paymentSurface: replacement.paymentSurface),
      base.copyWith(lockAccentSurface: replacement.lockAccentSurface),
      base.copyWith(lockKeySurface: replacement.lockKeySurface),
    ];
    for (var index = 0; index < copies.length; index++) {
      final expected = _values(base);
      expected[index] = _values(replacement)[index];
      expect(_values(copies[index]), expected);
    }
  });

  test('lerp covers every field at endpoints and midpoint', () {
    final light = AppColorScheme.light;
    final dark = AppColorScheme.dark;
    for (final t in [0.0, 0.5, 1.0]) {
      expect(
        _values(light.lerp(dark, t)),
        List.generate(
          _values(light).length,
          (index) =>
              Color.lerp(_values(light)[index], _values(dark)[index], t)!,
        ),
      );
    }
    expect(light.lerp(null, .5), same(light));
  });

  test('AppTheme registers semantic palettes and interpolates them', () {
    ScreenUtil.configure(
      data: const MediaQueryData(size: AppConstants.designSize),
      designSize: AppConstants.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
    );
    final light = AppTheme.light;
    final dark = AppTheme.dark;
    expect(light.extension<AppColorScheme>(), same(AppColorScheme.light));
    expect(dark.extension<AppColorScheme>(), same(AppColorScheme.dark));
    expect(
      _values(ThemeData.lerp(light, dark, .5).extension<AppColorScheme>()!),
      _values(AppColorScheme.light.lerp(AppColorScheme.dark, .5)),
    );
  });

  testWidgets('context colors and gradient consume the installed extension', (
    tester,
  ) async {
    final custom = AppColorScheme.light.copyWith(
      onboardingGradientStart: AppColors.paymentSurface,
      onboardingGradientMiddle: AppColors.primarySurface,
      onboardingGradientEnd: AppColors.creditSurface,
    );
    late AppColorScheme selected;
    late LinearGradient gradient;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light.copyWith(extensions: [custom]),
          home: Builder(
            builder: (context) {
              selected = context.appColors;
              gradient = AppGradients.onboardingCard(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, same(custom));
    expect(gradient.begin, Alignment.bottomLeft);
    expect(gradient.end, Alignment.topRight);
    expect(gradient.colors, [
      custom.onboardingGradientStart,
      custom.onboardingGradientMiddle,
      custom.onboardingGradientEnd,
    ]);
  });
}
