import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/fade_transition_page.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/colors/app_color_scheme.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:daftariapp/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:daftariapp/features/onboarding/presentation/widgets/onboarding_page_indicator.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_test_setup.dart';

class _Storage extends Mock implements LocalStorageService {}

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} ${mode.name}: next, swipe, finish', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final storage = LocalStorageService(
          await SharedPreferences.getInstance(),
        );
        final router = AppRouter.create(localStorage: storage);
        await tester.pumpWidget(
          DaftariApp(router: router, locale: locale, themeMode: mode),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(OnboardingScreen));
        final l10n = AppLocalizations.of(context)!;
        final colors = Theme.of(context).colorScheme;
        final gradient = tester
            .widgetList<Container>(find.byType(Container))
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.gradient)
            .whereType<LinearGradient>()
            .first;
        expect(gradient.colors, [
          context.appColors.onboardingGradientStart,
          context.appColors.onboardingGradientMiddle,
          context.appColors.onboardingGradientEnd,
        ]);
        expect(
          tester
              .widget<Text>(find.text(l10n.onboardingInstantPayment))
              .style!
              .color,
          context.appColors.paymentColor,
        );
        expect(
          tester
              .widget<Text>(find.text(l10n.onboardingSampleAmount))
              .style!
              .color,
          context.appColors.creditColor,
        );
        final badge =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text(l10n.onboardingSaved),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(badge.color, colors.primary);
        expect(badge.boxShadow!.single.color, AppColors.shadow);
        expect(
          tester.widget<Text>(find.text(l10n.onboardingSaved)).style!.color,
          colors.onPrimary,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
          colors.onPrimary,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.timer)).color,
          AppColors.warning,
        );
        expect(
          Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          mode == ThemeMode.dark ? AppColors.darkBackground : AppColors.paper,
        );
        expect(find.text(l10n.onboardingTitle1), findsOneWidget);
        expect(storage.onboardingCompleted, isFalse);
        final semantics = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel(
            l10n.onboardingPageLabel(1, 3, l10n.onboardingTitle1),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await tester.tap(find.byKey(const ValueKey('onboarding-next')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.onboardingTitle2), findsOneWidget);
        await tester.drag(
          find.byType(PageView),
          Offset(locale.languageCode == 'ar' ? 350 : -350, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.onboardingTitle3), findsOneWidget);
        expect(find.text(l10n.onboardingStart), findsOneWidget);
        expect(storage.onboardingCompleted, isFalse);
        await tester.tap(find.byKey(const ValueKey('onboarding-next')));
        await tester.pumpAndSettle();
        expect(storage.onboardingCompleted, isTrue);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      });
    }
  }

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('${locale.languageCode} system theme updates semantic colors', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final router = AppRouter.create(localStorage: storage);
      await tester.pumpWidget(DaftariApp(router: router, locale: locale));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(OnboardingScreen)).appColors.paperBackground,
        AppColorScheme.light.paperBackground,
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingScreen));
      expect(
        context.appColors.paperBackground,
        AppColorScheme.dark.paperBackground,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        context.appColors.paperBackground,
      );
      expect(
        tester
            .widget<Text>(find.text(context.l10n.onboardingInstantPayment))
            .style!
            .color,
        context.appColors.paymentColor,
      );
      expect(
        tester
            .widget<Text>(find.text(context.l10n.onboardingSampleAmount))
            .style!
            .color,
        context.appColors.creditColor,
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(OnboardingScreen)).appColors.paperBackground,
        AppColorScheme.light.paperBackground,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  testWidgets('Skip persists and subsequent launch bypasses onboarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final router = AppRouter.create(localStorage: storage);
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(storage.onboardingCompleted, isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    final returning = AppRouter.create(
      localStorage: LocalStorageService(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(DaftariApp(router: returning));
    await tester.pumpAndSettle();
    expect(returning.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(OnboardingScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    returning.dispose();
  });

  for (final size in [
    const Size(320, 640),
    const Size(840, 400),
    const Size(800, 1280),
    const Size(1440, 900),
  ]) {
    testWidgets('all pages fit $size with enlarged Arabic text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final router = AppRouter.create(localStorage: storage);
      await tester.pumpWidget(DaftariApp(router: router));
      await tester.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        expect(tester.takeException(), isNull);
        if (page < 2) {
          await tester.tap(find.byKey(const ValueKey('onboarding-next')));
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  testWidgets('save failure displays localized error and allows retry', (
    tester,
  ) async {
    final storage = _Storage();
    when(() => storage.onboardingCompleted).thenReturn(false);
    when(() => storage.setOnboardingCompleted(true))
        .thenThrow(Exception('disk unavailable'));
    final router = AppRouter.create(
      localStorage: storage,
      createOnboardingCubit: () => OnboardingCubit(storage),
    );
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save your preference. Please try again."),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    when(() => storage.setOnboardingCompleted(true)).thenAnswer((_) async {});
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets(
    'reduced motion advances pages immediately, completes once, and bypasses after restart',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final router = AppRouter.create(localStorage: storage);
      addTearDown(router.dispose);
      final locations = <String>[];
      void recordLocation() =>
          locations.add(router.routeInformationProvider.value.uri.path);
      router.routerDelegate.addListener(recordLocation);
      addTearDown(() => router.routerDelegate.removeListener(recordLocation));

      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pump(SplashScreen.displayDuration);
      await tester.pumpAndSettle();

      final indicatorDots = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(OnboardingPageIndicator),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(indicatorDots, hasLength(3));
      for (final dot in indicatorDots) {
        expect(dot.duration, Duration.zero);
      }

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Know every customer'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Your data is safe'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      expect(storage.onboardingCompleted, isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(locations.where((path) => path == '/').length, 1);

      router.go('/onboarding');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');

      await tester.pumpWidget(const SizedBox());
      final returning = AppRouter.create(
        localStorage: LocalStorageService(
          await SharedPreferences.getInstance(),
        ),
      );
      addTearDown(returning.dispose);
      await tester.pumpWidget(
        DaftariApp(router: returning, locale: const Locale('en')),
      );
      await tester.pump(SplashScreen.displayDuration);
      await tester.pumpAndSettle();
      expect(returning.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending completion disables duplicate taps, shows shared loader, and navigates once',
    (tester) async {
      final pending = Completer<void>();
      var completed = false;
      final storage = _Storage();
      when(() => storage.onboardingCompleted).thenAnswer((_) => completed);
      when(() => storage.setOnboardingCompleted(true)).thenAnswer((_) async {
        await pending.future;
        completed = true;
      });
      final router = AppRouter.create(
        localStorage: storage,
        createOnboardingCubit: () => OnboardingCubit(storage),
      );
      addTearDown(router.dispose);
      final locations = <String>[];
      void recordLocation() =>
          locations.add(router.routeInformationProvider.value.uri.path);
      router.routerDelegate.addListener(recordLocation);
      addTearDown(() => router.routerDelegate.removeListener(recordLocation));

      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      final indicatorDots = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(OnboardingPageIndicator),
          matching: find.byType(AnimatedContainer),
        ),
      );
      for (final dot in indicatorDots) {
        expect(dot.duration, const Duration(milliseconds: 200));
      }

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('onboarding-skip')))
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-next')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-skip')),
        warnIfMissed: false,
      );
      await tester.pump();
      verify(() => storage.setOnboardingCompleted(true)).called(1);

      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final navigator = tester.widget<Navigator>(find.byType(Navigator).first);
      expect(navigator.pages.last, isA<FadeTransitionPage<dynamic>>());

      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(locations.where((path) => path == '/').length, 1);
      verifyNever(() => storage.setOnboardingCompleted(any()));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
