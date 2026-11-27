import 'dart:async';
import 'dart:convert';

import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/spacing/app_spacing.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_scaffold.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

class _ControllableAssetBundle extends CachingAssetBundle {
  _ControllableAssetBundle({
    required this.fallback,
    this.pendingAssetKey,
    this.pendingCompleter,
    this.corruptAssetKey,
  });

  final AssetBundle fallback;
  final String? pendingAssetKey;
  final Completer<ByteData>? pendingCompleter;
  final String? corruptAssetKey;

  @override
  Future<ByteData> load(String key) {
    if (corruptAssetKey != null && key == corruptAssetKey) {
      final bytes = Uint8List.fromList(utf8.encode('{corrupt lottie json'));
      return Future<ByteData>.value(ByteData.sublistView(bytes));
    }
    if (pendingCompleter != null && key == pendingAssetKey) {
      return pendingCompleter!.future;
    }
    return fallback.load(key);
  }
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = foreground.computeLuminance();
  final l2 = background.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pumpFeedbackApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeMode mode = ThemeMode.light,
  bool disableAnimations = false,
  AssetBundle? bundle,
}) async {
  Widget app = ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      locale: locale,
      supportedLocales: AppConstants.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      home: AppScaffold(body: child),
    ),
  );
  if (bundle != null) {
    app = DefaultAssetBundle(bundle: bundle, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pump();
}

Future<LottieComposition?> _waitForDecodedComposition(
  WidgetTester tester, {
  Finder? scope,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final finder = scope == null
      ? find.byType(RawLottie)
      : find.descendant(of: scope, matching: find.byType(RawLottie));
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (tester.any(finder)) {
      final composition = tester.widget<RawLottie>(finder).composition;
      if (composition != null) {
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

Future<LottieComposition> _expectDecodedComposition(
  WidgetTester tester, {
  Finder? scope,
}) async {
  final composition = await _waitForDecodedComposition(tester, scope: scope);
  expect(
    composition,
    isNotNull,
    reason: 'Expected local Lottie asset to decode a non-null composition.',
  );
  expect(composition!.durationFrames, greaterThan(0));
  return composition;
}

void main() {
  setUp(() {
    Lottie.cache.clear();
  });

  group('DaftariLoading', () {
    testWidgets(
      'shows static loading visual while asset load is pending and swaps to animation when decoded',
      (tester) async {
        final completer = Completer<ByteData>();
        final bundle = _ControllableAssetBundle(
          fallback: rootBundle,
          pendingAssetKey: DaftariLoading.assetPath,
          pendingCompleter: completer,
        );

        await _pumpFeedbackApp(
          tester,
          Column(
            children: [
              AppButton(label: 'Save', isLoading: true, onPressed: () {}),
              const Expanded(child: DaftariLoading.screen()),
            ],
          ),
          bundle: bundle,
        );

        // Both inline button and screen variants show visible static feedback
        // immediately while the Lottie asset is still pending.
        expect(
          find.descendant(
            of: find.byType(AppButton),
            matching: find.byIcon(Icons.hourglass_top_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is DaftariLoading &&
                  w.variant == DaftariLoadingVariant.screen,
            ),
            matching: find.byIcon(Icons.hourglass_top_rounded),
          ),
          findsOneWidget,
        );
        expect(find.byType(RawLottie), findsNothing);

        // Release the asset bytes and verify both variants replace the static
        // visual with decoded Lottie animations.
        final realBytes = await tester.runAsync(
          () => rootBundle.load(DaftariLoading.assetPath),
        );
        completer.complete(realBytes!);

        await _expectDecodedComposition(tester, scope: find.byType(AppButton));
        await _expectDecodedComposition(
          tester,
          scope: find.byWidgetPredicate(
            (w) =>
                w is DaftariLoading &&
                w.variant == DaftariLoadingVariant.screen,
          ),
        );
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'applies theme-aware contrast (>= 3:1) in light and dark modes, explicit tint, and reduced motion',
      (tester) async {
        // Light mode default screen loader.
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(),
          mode: ThemeMode.light,
        );
        await _expectDecodedComposition(tester);
        final lightLottie = tester.widget<RawLottie>(find.byType(RawLottie));
        final lightStroke =
            lightLottie.delegates!.values!.single.value! as Color;
        expect(lightStroke, AppColors.primary);
        expect(
          _contrastRatio(lightStroke, AppColors.background),
          greaterThanOrEqualTo(3.0),
        );
        expect(
          _contrastRatio(lightStroke, AppColors.surface),
          greaterThanOrEqualTo(3.0),
        );

        // Dark mode default screen loader.
        await tester.pumpWidget(const SizedBox());
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(),
          mode: ThemeMode.dark,
        );
        await _expectDecodedComposition(tester);
        final darkLottie = tester.widget<RawLottie>(find.byType(RawLottie));
        final darkStroke = darkLottie.delegates!.values!.single.value! as Color;
        expect(darkStroke, AppColors.mint);
        expect(
          _contrastRatio(darkStroke, AppColors.darkBackground),
          greaterThanOrEqualTo(3.0),
        );
        expect(
          _contrastRatio(darkStroke, AppColors.darkSurface),
          greaterThanOrEqualTo(3.0),
        );

        // Explicit inline tint.
        await tester.pumpWidget(const SizedBox());
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.inline(color: AppColors.credit),
          mode: ThemeMode.light,
        );
        await _expectDecodedComposition(tester);
        final tintedLottie = tester.widget<RawLottie>(find.byType(RawLottie));
        expect(
          tintedLottie.delegates!.values!.single.value,
          equals(AppColors.credit),
        );

        // Reduced motion fallback uses the same theme color.
        await tester.pumpWidget(const SizedBox());
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(),
          mode: ThemeMode.light,
          disableAnimations: true,
        );
        await tester.pumpAndSettle();
        final staticIcon = tester.widget<Icon>(
          find.byIcon(Icons.hourglass_top_rounded),
        );
        expect(staticIcon.color, AppColors.primary);
        expect(
          _contrastRatio(staticIcon.color!, AppColors.background),
          greaterThanOrEqualTo(3.0),
        );
      },
    );

    testWidgets(
      'inline variant fits compact buttons, decodes local Lottie offline, and exposes localized semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final locale in AppConstants.supportedLocales) {
            await tester.pumpWidget(const SizedBox());
            Lottie.cache.clear();
            await _pumpFeedbackApp(
              tester,
              Center(
                child: AppButton(
                  label: 'Save',
                  isLoading: true,
                  onPressed: () {},
                ),
              ),
              locale: locale,
            );

            await _expectDecodedComposition(tester);

            final loadingFinder = find.byType(DaftariLoading);
            expect(loadingFinder, findsOneWidget);

            final lottieFinder = find.byType(Lottie);
            expect(lottieFinder, findsOneWidget);
            final lottie = tester.widget<Lottie>(lottieFinder);
            expect(lottie.repeat, isTrue);

            final buttonSize = tester.getSize(find.byType(FilledButton));
            final loaderSize = tester.getSize(loadingFinder);
            expect(loaderSize.width, lessThanOrEqualTo(buttonSize.width));
            expect(loaderSize.height, lessThanOrEqualTo(buttonSize.height));

            final expectedLabel = locale.languageCode == 'ar'
                ? 'جارٍ التحميل'
                : 'Loading';
            final node = tester.getSemantics(loadingFinder);
            expect(node.label, contains(expectedLabel));
            expect(node.flagsCollection.isLiveRegion, isTrue);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'screen variant centers loader, displays optional message, and decodes local Lottie offline',
      (tester) async {
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(message: 'جارٍ تجهيز الدفتر'),
          locale: const Locale('ar'),
          mode: ThemeMode.dark,
        );
        await _expectDecodedComposition(tester);

        expect(find.byType(DaftariLoading), findsOneWidget);
        expect(find.text('جارٍ تجهيز الدفتر'), findsOneWidget);
        final visualSize = tester.getSize(find.byType(Lottie));
        expect(visualSize.width, AppSpacing.loadingScreenSize);
        expect(visualSize.height, AppSpacing.loadingScreenSize);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reduced motion renders static equivalent without Lottie for inline and screen variants',
      (tester) async {
        await _pumpFeedbackApp(
          tester,
          const Column(
            children: [
              AppButton(label: 'Save', isLoading: true, onPressed: null),
              Expanded(child: DaftariLoading.screen(message: 'Loading ledger')),
            ],
          ),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();

        expect(find.byType(Lottie), findsNothing);
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNWidgets(2));
        expect(find.text('Loading ledger'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'corrupt loading fixture fails positive decode check and falls back to static visual',
      (tester) async {
        final bundle = _ControllableAssetBundle(
          fallback: rootBundle,
          corruptAssetKey: DaftariLoading.assetPath,
        );
        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(),
          bundle: bundle,
        );

        final composition = await _waitForDecodedComposition(
          tester,
          timeout: const Duration(milliseconds: 250),
        );
        expect(composition, isNull);
        expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AppSuccessDialog', () {
    testWidgets(
      'decodes local success Lottie offline, exposes localized semantics, and dismisses via OK',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final locale in AppConstants.supportedLocales) {
            await tester.pumpWidget(const SizedBox());
            Lottie.cache.clear();
            var completed = false;
            await _pumpFeedbackApp(
              tester,
              Builder(
                builder: (context) => AppButton(
                  label: 'Show',
                  onPressed: () async {
                    await AppSuccessDialog.show(
                      context,
                      title: locale.languageCode == 'ar' ? 'تم الحفظ' : 'Saved',
                      message: locale.languageCode == 'ar'
                          ? 'تم حفظ البيانات بنجاح'
                          : 'Changes have been saved.',
                    );
                    completed = true;
                  },
                ),
              ),
              locale: locale,
            );

            await tester.tap(find.text('Show'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            await _expectDecodedComposition(tester);

            expect(find.byType(AppSuccessDialog), findsOneWidget);
            expect(find.byType(Lottie), findsOneWidget);
            expect(tester.widget<Lottie>(find.byType(Lottie)).repeat, isFalse);

            final expectedSemantics = locale.languageCode == 'ar'
                ? 'تم بنجاح'
                : 'Success';
            expect(find.bySemanticsLabel(expectedSemantics), findsOneWidget);

            final okLabel = locale.languageCode == 'ar' ? 'حسناً' : 'OK';
            expect(find.text(okLabel), findsOneWidget);
            await tester.tap(find.text(okLabel));
            await tester.pumpAndSettle();

            expect(completed, isTrue);
            expect(find.byType(AppSuccessDialog), findsNothing);
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('decodes debt-paid Lottie success asset independently', (
      tester,
    ) async {
      await _pumpFeedbackApp(
        tester,
        const AppSuccessDialog(
          title: 'Done',
          assetPath: AppSuccessDialog.debtPaidAssetPath,
        ),
      );

      final composition = await _expectDecodedComposition(tester);
      expect(composition.durationFrames, closeTo(24, 0.05));
      expect(composition.frameRate, 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'decodes transaction-added Lottie success asset independently',
      (tester) async {
        await _pumpFeedbackApp(
          tester,
          const AppSuccessDialog(
            title: 'Done',
            assetPath: AppSuccessDialog.transactionAddedAssetPath,
          ),
        );

        final composition = await _expectDecodedComposition(tester);
        expect(composition.durationFrames, closeTo(51, 0.05));
        expect(composition.frameRate, 60);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reduced motion renders static checkmark equivalent without Lottie',
      (tester) async {
        await _pumpFeedbackApp(
          tester,
          const AppSuccessDialog(title: 'Saved', message: 'All set'),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();

        expect(find.byType(Lottie), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.text('Saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'corrupt success fixture fails positive decode check and falls back to static checkmark',
      (tester) async {
        final bundle = _ControllableAssetBundle(
          fallback: rootBundle,
          corruptAssetKey: AppSuccessDialog.defaultAssetPath,
        );
        await _pumpFeedbackApp(
          tester,
          const AppSuccessDialog(title: 'Saved'),
          bundle: bundle,
        );

        final composition = await _waitForDecodedComposition(
          tester,
          timeout: const Duration(milliseconds: 250),
        );
        expect(composition, isNull);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AppErrorDialog', () {
    testWidgets(
      'decodes local error Lottie offline, returns false on OK and barrier dismissal',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          bool? result;
          await _pumpFeedbackApp(
            tester,
            Builder(
              builder: (context) => AppButton(
                label: 'Fail',
                onPressed: () async {
                  result = await AppErrorDialog.show(
                    context,
                    message: 'Could not save.',
                  );
                },
              ),
            ),
          );

          await tester.tap(find.text('Fail'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await _expectDecodedComposition(tester);

          expect(find.byType(AppErrorDialog), findsOneWidget);
          expect(tester.widget<Lottie>(find.byType(Lottie)).repeat, isFalse);
          expect(find.bySemanticsLabel('Error'), findsOneWidget);
          expect(find.text('Something went wrong'), findsOneWidget);
          expect(find.text('Could not save.'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);

          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(result, isFalse);

          // Barrier dismissal also returns false.
          result = null;
          await tester.tap(find.text('Fail'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await _expectDecodedComposition(tester);
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(result, isFalse);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'retry action returns true on Retry and false on OK in Arabic RTL',
      (tester) async {
        bool? result;
        await _pumpFeedbackApp(
          tester,
          Builder(
            builder: (context) => AppButton(
              label: 'Open',
              onPressed: () async {
                result = await AppErrorDialog.show(
                  context,
                  message: 'تعذر الحفظ',
                  showRetry: true,
                );
              },
            ),
          ),
          locale: const Locale('ar'),
          mode: ThemeMode.dark,
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        await _expectDecodedComposition(tester);

        expect(find.text('إعادة المحاولة'), findsOneWidget);
        expect(find.text('حسناً'), findsOneWidget);
        await tester.tap(find.text('إعادة المحاولة'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        result = null;
        await tester.tap(find.text('Open'));
        await tester.pump();
        await _expectDecodedComposition(tester);
        await tester.tap(find.text('حسناً'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
    );

    testWidgets(
      'reduced motion renders static error equivalent without Lottie',
      (tester) async {
        await _pumpFeedbackApp(
          tester,
          const AppErrorDialog(message: 'Failed'),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();

        expect(find.byType(Lottie), findsNothing);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'corrupt error fixture fails positive decode check and falls back to static error icon',
      (tester) async {
        final bundle = _ControllableAssetBundle(
          fallback: rootBundle,
          corruptAssetKey: AppErrorDialog.defaultAssetPath,
        );
        await _pumpFeedbackApp(
          tester,
          const AppErrorDialog(message: 'Failed'),
          bundle: bundle,
        );

        final composition = await _waitForDecodedComposition(
          tester,
          timeout: const Duration(milliseconds: 250),
        );
        expect(composition, isNull);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dialogs and screen loading fit narrow RTL screen with enlarged text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _pumpFeedbackApp(
          tester,
          const AppErrorDialog(
            title: 'تعذر إتمام العملية',
            message: 'يرجى التحقق من البيانات والمحاولة مرة أخرى لاحقًا.',
            onRetry: _noop,
          ),
          locale: const Locale('ar'),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await _pumpFeedbackApp(
          tester,
          const DaftariLoading.screen(message: 'جارٍ تحميل بيانات الدفتر...'),
          locale: const Locale('ar'),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

void _noop() {}
