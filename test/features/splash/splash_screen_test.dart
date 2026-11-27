import 'dart:async';
import 'dart:convert';

import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:daftariapp/features/splash/presentation/widgets/splash_branding.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

class _ControllableAssetBundle extends CachingAssetBundle {
  _ControllableAssetBundle({
    required this.fallback,
    this.pendingAssets = const {},
    this.corruptAssets = const {},
  });

  final AssetBundle fallback;
  final Map<String, Completer<ByteData>> pendingAssets;
  final Set<String> corruptAssets;

  @override
  Future<ByteData> load(String key) {
    if (corruptAssets.contains(key)) {
      final bytes = Uint8List.fromList(utf8.encode('{corrupt lottie json'));
      return Future<ByteData>.value(ByteData.sublistView(bytes));
    }
    final pending = pendingAssets[key];
    if (pending != null) {
      return pending.future;
    }
    return fallback.load(key);
  }
}

Widget _app({
  required Locale locale,
  required ThemeMode mode,
  required VoidCallback onFinished,
  bool hold = false,
  bool disableAnimations = false,
  AssetBundle? bundle,
}) {
  Widget app = ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, child) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (context, appChild) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(disableAnimations: disableAnimations),
          child: appChild!,
        );
      },
      home: SplashScreen(onFinished: onFinished, hold: hold),
    ),
  );
  if (bundle != null) {
    app = DefaultAssetBundle(bundle: bundle, child: app);
  }
  return app;
}

Future<LottieComposition?> _waitForDecodedComposition(
  WidgetTester tester, {
  required Finder scope,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final finder = find.descendant(of: scope, matching: find.byType(RawLottie));
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (tester.any(finder)) {
      final composition = tester.widget<RawLottie>(finder).composition;
      if (composition != null && composition.durationFrames > 0) {
        return composition;
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  return null;
}

void main() {
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${locale.languageCode} ${mode.name} splash matches branding and uses shared loader',
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
          expect(find.byType(DaftariLoading), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
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

  testWidgets('splash decodes local splash_icon and loading Lottie assets', (
    tester,
  ) async {
    Lottie.cache.clear();
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        mode: ThemeMode.light,
        onFinished: () {},
      ),
    );
    await tester.pump();

    final logoComposition = await _waitForDecodedComposition(
      tester,
      scope: find.byType(SplashBranding),
    );
    final loaderComposition = await _waitForDecodedComposition(
      tester,
      scope: find.byType(DaftariLoading),
    );

    expect(logoComposition, isNotNull);
    expect(logoComposition!.durationFrames, greaterThan(0));
    expect(loaderComposition, isNotNull);
    expect(loaderComposition!.durationFrames, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'splash shows static logo and hourglass while Lottie loads or fails',
    (tester) async {
      Lottie.cache.clear();
      final pendingSplash = Completer<ByteData>();
      final pendingLoader = Completer<ByteData>();
      final bundle = _ControllableAssetBundle(
        fallback: rootBundle,
        pendingAssets: {
          SplashBranding.assetPath: pendingSplash,
          DaftariLoading.assetPath: pendingLoader,
        },
      );

      await tester.pumpWidget(
        _app(
          locale: const Locale('en'),
          mode: ThemeMode.light,
          bundle: bundle,
          onFinished: () {},
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SplashBranding),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);

      pendingSplash.complete(await rootBundle.load(SplashBranding.assetPath));
      pendingLoader.complete(await rootBundle.load(DaftariLoading.assetPath));

      expect(
        await _waitForDecodedComposition(
          tester,
          scope: find.byType(SplashBranding),
        ),
        isNotNull,
      );
      expect(
        await _waitForDecodedComposition(
          tester,
          scope: find.byType(DaftariLoading),
        ),
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox());
      Lottie.cache.clear();
      await tester.pumpWidget(
        _app(
          locale: const Locale('en'),
          mode: ThemeMode.dark,
          bundle: _ControllableAssetBundle(
            fallback: rootBundle,
            corruptAssets: {SplashBranding.assetPath, DaftariLoading.assetPath},
          ),
          onFinished: () {},
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(SplashBranding),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion uses static logo, static loader and skips fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        mode: ThemeMode.light,
        disableAnimations: true,
        onFinished: () {},
      ),
    );
    await tester.pump();

    expect(find.byType(RawLottie), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SplashBranding),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hold defers completion until released and fires once', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        mode: ThemeMode.light,
        hold: true,
        onFinished: () => completions++,
      ),
    );
    await tester.pump(SplashScreen.displayDuration);
    expect(completions, 0);

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        mode: ThemeMode.light,
        hold: false,
        onFinished: () => completions++,
      ),
    );
    await tester.pump();
    expect(completions, 1);

    await tester.pump(SplashScreen.displayDuration);
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

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
