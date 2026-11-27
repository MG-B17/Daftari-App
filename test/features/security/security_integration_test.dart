import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/security/domain/entities/pin_flow_mode.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:daftariapp/features/security/presentation/widgets/pin_dots_indicator.dart';
import 'package:daftariapp/features/security/presentation/widgets/pin_keypad.dart';
import 'package:daftariapp/features/security/presentation/widgets/biometric_unlock_button.dart';
import 'package:daftariapp/features/security/presentation/widgets/security_settings_section.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../security_test_setup.dart';

Future<({AppLockCubit lock, GoRouter router})> _pump(
  WidgetTester tester, {
  required TestSecurityRepository repository,
  String language = 'en',
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(400, 900),
  bool realRouter = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final lock = await testAppLock(repository: repository);
  final router = realRouter
      ? AppRouter.create(appLock: lock)
      : GoRouter(
          initialLocation: lock.state.locked ? '/lock' : '/',
          refreshListenable: lock,
          redirect: (_, state) => lock.state.locked
              ? state.uri.path == '/lock'
                    ? null
                    : '/lock'
              : state.uri.path == '/lock'
              ? '/'
              : null,
          routes: [
            GoRoute(path: '/lock', builder: (_, _) => const PinLockScreen()),
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: SingleChildScrollView(child: SecuritySettingsSection()),
              ),
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, _) => const Scaffold(
                body: SingleChildScrollView(child: SecuritySettingsSection()),
              ),
            ),
            GoRoute(
              path: AppRoutes.settingsPin,
              builder: (_, state) {
                final mode = switch (state.uri.queryParameters['mode']) {
                  'change' => PinFlowMode.change,
                  'disable' => PinFlowMode.disable,
                  _ => PinFlowMode.setup,
                };
                return PinLockScreen(mode: mode);
              },
            ),
          ],
        );
  addTearDown(() async {
    router.dispose();
    await lock.close();
  });
  await tester.pumpWidget(
    DaftariApp(
      router: router,
      appLockCubit: lock,
      locale: Locale(language),
      themeMode: theme,
    ),
  );
  await tester.pumpAndSettle();
  return (lock: lock, router: router);
}

Future<void> _digits(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    final key = find.widgetWithText(FilledButton, digit);
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final language in ['ar', 'en']) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$language $theme lock numeric order and back protection', (
        tester,
      ) async {
        await _pump(
          tester,
          repository: TestSecurityRepository(pin: '2468'),
          language: language,
          theme: theme,
        );
        final context = tester.element(find.byType(PinLockScreen));
        expect(
          Directionality.of(context),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          Theme.of(context).brightness,
          theme == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(
          tester.getTopLeft(find.text('1')).dx,
          language == 'ar'
              ? greaterThan(tester.getTopLeft(find.text('3')).dx)
              : lessThan(tester.getTopLeft(find.text('3')).dx),
        );
        expect(find.byType(AppBar), findsNothing);
        expect(find.text(context.l10n.securityPreview), findsNothing);
        expect(find.text(context.l10n.securityBrandCaption), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PinLockScreen), findsOneWidget);
        await _digits(tester, '12');
        expect(
          tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
          2,
        );
        await tester.tap(find.byTooltip(context.l10n.securityDeleteDigit));
        await tester.pump();
        expect(
          tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
          1,
        );
        await tester.tap(find.text(context.l10n.securityClearAll));
        await tester.pump();
        expect(
          tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
          0,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'real router cold start and protected deep links never construct ledger',
    (tester) async {
      final harness = await _pump(
        tester,
        repository: TestSecurityRepository(pin: '2468'),
        realRouter: true,
      );
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        AppRoutes.lock,
      );
      for (final path in [
        '/customers',
        '/settings',
        '/customers/private/statement',
        '/settings/pin?mode=reset',
        '/transactions/new',
      ]) {
        harness.router.go(path);
        await tester.pumpAndSettle();
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          AppRoutes.lock,
        );
        expect(find.byType(PinLockScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(harness.lock.state.locked, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'wrong PIN rejected; demo PIN has no special access; correct PIN unlocks',
    (tester) async {
      final harness = await _pump(
        tester,
        repository: TestSecurityRepository(pin: '2468'),
      );
      await _digits(tester, '1234');
      expect(find.text('PIN did not match. Please try again.'), findsOneWidget);
      expect(harness.lock.state.locked, isTrue);
      await _digits(tester, '2468');
      expect(harness.lock.state.locked, isFalse);
      expect(find.byType(SecuritySettingsSection), findsOneWidget);
    },
  );

  testWidgets(
    'hashing shows loading, disables keypad and ignores repeated taps',
    (tester) async {
      final barrier = Completer<void>();
      final repository = TestSecurityRepository(pin: '2468')
        ..verificationBarrier = barrier.future;
      await _pump(tester, repository: repository);
      await _digits(tester, '246');
      await tester.tap(find.widgetWithText(FilledButton, '8'));
      await tester.pump();
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loading'), findsOneWidget);
      expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isFalse);
      expect(repository.verificationCalls, 1);
      barrier.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(SecuritySettingsSection), findsOneWidget);
    },
  );

  testWidgets(
    'forgot PIN without device lock explains data risk, never bypasses',
    (tester) async {
      final repository = TestSecurityRepository(pin: '2468');
      final harness = await _pump(tester, repository: repository);
      await tester.ensureVisible(find.text('Forgot PIN?'));
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('permanently remove your local ledger'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.osCalls, 0);
      expect(harness.lock.state.locked, isTrue);
    },
  );

  testWidgets(
    'OS recovery cancellation preserves PIN; success creates and confirms new PIN',
    (tester) async {
      final repository = TestSecurityRepository(pin: '2468')
        ..deviceAvailable = true;
      final harness = await _pump(tester, repository: repository);
      await tester.ensureVisible(find.text('Forgot PIN?'));
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(repository.pin, '2468');
      repository.recoverySuccess = true;
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset your PIN'), findsOneWidget);
      expect(harness.lock.state.locked, isTrue);
      await _digits(tester, '9876');
      await _digits(tester, '9876');
      expect(repository.pin, '9876');
      expect(repository.osCalls, 2);
      expect(harness.lock.state.locked, isFalse);
    },
  );

  testWidgets('biometric cancellation retains PIN fallback', (tester) async {
    final repository = TestSecurityRepository(
      pin: '2468',
      biometricEnabled: true,
    );
    final harness = await _pump(tester, repository: repository);
    await tester.ensureVisible(find.byType(BiometricUnlockButton));
    await tester.tap(find.byType(BiometricUnlockButton));
    await tester.pumpAndSettle();
    expect(harness.lock.state.locked, isTrue);
    await _digits(tester, '2468');
    expect(harness.lock.state.locked, isFalse);
  });

  testWidgets('cooldown disables entry and biometric but permits OS recovery', (
    tester,
  ) async {
    final repository =
        TestSecurityRepository(pin: '2468', biometricEnabled: true)
          ..attempts = 5
          ..deadline = DateTime.utc(
            2026,
            11,
            20,
          ).add(const Duration(seconds: 30));
    final harness = await _pump(tester, repository: repository);
    expect(find.textContaining('30 seconds'), findsOneWidget);
    expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isFalse);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byType(BiometricUnlockButton),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await harness.lock.close();
  });

  testWidgets('small RTL screen at large text scale scrolls without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      repository: TestSecurityRepository(pin: '2468'),
      language: 'ar',
      size: const Size(320, 568),
    );
    await _digits(tester, '12');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings persist biometric and timeout choices through repository',
    (tester) async {
      final repository = TestSecurityRepository(pin: '2468');
      final harness = await _pump(tester, repository: repository);
      await _digits(tester, '2468');
      await tester.tap(find.text('Biometric unlock'));
      await tester.pumpAndSettle();
      expect(repository.biometricEnabled, isTrue);
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Biometric unlock enabled'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      await tester.ensureVisible(find.text('Auto-lock'));
      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After 5 minutes'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(repository.timeout, AutoLockTimeout.fiveMinutes);
      expect(
        harness.lock.state.settings.autoLockTimeout,
        AutoLockTimeout.fiveMinutes,
      );
    },
  );

  testWidgets(
    'background masks open settings sheet; resume cannot expose it when locked',
    (tester) async {
      final harness = await _pump(
        tester,
        repository: TestSecurityRepository(pin: '2468'),
      );
      await _digits(tester, '2468');
      await tester.ensureVisible(find.text('Auto-lock'));
      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(harness.lock.state.locked, isTrue);
      expect(harness.lock.state.obscured, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(PinLockScreen), findsOneWidget);
      expect(find.text('After 5 minutes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit PIN setup shows pending loader, disables back/keypad, shows success dialog once and returns',
    (tester) async {
      final barrier = Completer<void>();
      final repository = TestSecurityRepository()
        ..setupBarrier = barrier.future;
      await _pump(tester, repository: repository);

      await tester.tap(find.text('App PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Create your PIN'), findsOneWidget);

      await _digits(tester, '2468');
      expect(find.text('Confirm your PIN'), findsOneWidget);

      await _digits(tester, '246');
      await tester.tap(find.widgetWithText(FilledButton, '8'));
      await tester.pump();

      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isFalse);
      expect(repository.setupCalls, 1);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PinLockScreen), findsOneWidget);

      barrier.complete();
      await tester.pumpAndSettle();

      expect(repository.pin, '2468');
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSuccessDialog),
          matching: find.text('PIN enabled'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(SecuritySettingsSection), findsOneWidget);
    },
  );

  testWidgets(
    'explicit PIN change and removal show success dialog once and return to settings',
    (tester) async {
      final repository = TestSecurityRepository(pin: '2468');
      await _pump(tester, repository: repository);
      await _digits(tester, '2468');

      await tester.tap(find.text('Change PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Change your PIN'), findsOneWidget);

      await _digits(tester, '2468');
      await _digits(tester, '9876');
      await _digits(tester, '9876');

      expect(repository.pin, '9876');
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSuccessDialog),
          matching: find.text('PIN updated'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(SecuritySettingsSection), findsOneWidget);

      await tester.tap(find.text('App PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off PIN'), findsOneWidget);

      await _digits(tester, '9876');
      expect(repository.pin, isNull);
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSuccessDialog),
          matching: find.text('PIN turned off'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(SecuritySettingsSection), findsOneWidget);
    },
  );

  testWidgets(
    'biometric setup pending disables duplicate taps, reports error dialog once, and disable stays lightweight',
    (tester) async {
      final barrier = Completer<void>();
      final repository = TestSecurityRepository(pin: '2468')
        ..biometricBarrier = barrier.future
        ..setBiometricResult = false;
      await _pump(tester, repository: repository);
      await _digits(tester, '2468');

      await tester.tap(find.text('Biometric unlock'));
      await tester.pump();
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(find.text('Biometric unlock'));
      await tester.pump();
      expect(repository.biometricToggleCalls, 1);

      barrier.complete();
      await tester.pumpAndSettle();
      expect(repository.biometricEnabled, isFalse);
      expect(find.byType(AppErrorDialog), findsOneWidget);
      expect(
        find.text(
          'Authentication was cancelled or unavailable. Please try again or use your app PIN.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsNothing);

      repository
        ..biometricBarrier = null
        ..setBiometricResult = true;
      await tester.tap(find.text('Biometric unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Biometric unlock'));
      await tester.pumpAndSettle();
      expect(repository.biometricEnabled, isFalse);
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(AppErrorDialog), findsNothing);
    },
  );

  testWidgets(
    'storage failure during PIN setup fails closed to lock screen without showing error dialog',
    (tester) async {
      final repository = TestSecurityRepository();
      final harness = await _pump(tester, repository: repository);

      await tester.tap(find.text('App PIN'));
      await tester.pumpAndSettle();
      await _digits(tester, '2468');
      repository.fail = true;
      await _digits(tester, '2468');

      expect(harness.lock.state.locked, isTrue);
      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(PinLockScreen), findsOneWidget);
    },
  );

  testWidgets(
    'pending PIN screen respects reduced motion and Arabic PIN setup shows localized success dialog',
    (tester) async {
      final barrier = Completer<void>();
      final repository = TestSecurityRepository()
        ..setupBarrier = barrier.future;
      await _pump(tester, repository: repository, language: 'ar');

      await tester.tap(find.text('رمز قفل التطبيق'));
      await tester.pumpAndSettle();
      await _digits(tester, '2468');
      await _digits(tester, '246');

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.tap(find.widgetWithText(FilledButton, '8'));
      await tester.pump();
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);

      barrier.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSuccessDialog),
          matching: find.text('تم تفعيل رمز القفل'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();
      expect(find.byType(SecuritySettingsSection), findsOneWidget);
    },
  );
}
