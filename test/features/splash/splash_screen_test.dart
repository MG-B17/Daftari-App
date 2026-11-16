import 'package:daftariapp/core/theme/app_colors.dart';
import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget _app({
  required Locale locale,
  required ThemeMode mode,
  required VoidCallback onFinished,
}) => ScreenUtilInit(
  designSize: AppConstants.designSize,
  builder: (context, child) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: SplashScreen(onFinished: onFinished),
  ),
);

void main() {
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${locale.languageCode} ${mode.name} splash matches branding',
        (tester) async {
          tester.view.physicalSize = const Size(390, 846);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var completions = 0;
          await tester.pumpWidget(
            _app(locale: locale, mode: mode, onFinished: () => completions++),
          );
          await tester.pump();
          final context = tester.element(find.byType(SplashScreen));
          final l10n = AppLocalizations.of(context)!;
          expect(find.text(l10n.appTitle), findsOneWidget);
          expect(find.text(l10n.splashTagline), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            mode == ThemeMode.dark ? AppColors.darkBackground : AppColors.paper,
          );
          expect(
            Directionality.of(context),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(completions, 0);
          await tester.pump(SplashScreen.displayDuration);
          expect(completions, 1);
          await tester.pump(const Duration(seconds: 2));
          expect(completions, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('disposing splash cancels pending navigation', (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        mode: ThemeMode.light,
        onFinished: () => completions++,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(SplashScreen.displayDuration);
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash fits narrow landscape with enlarged Arabic text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _app(locale: const Locale('ar'), mode: ThemeMode.dark, onFinished: () {}),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
