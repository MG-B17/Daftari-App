import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/core/widgets/app_feedback_dialog.dart';
import 'package:daftariapp/features/auth/forgot_password/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import 'package:daftariapp/features/auth/forgot_password/presentation/screens/forgot_password_screen.dart';
import 'package:daftariapp/features/auth/login/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/login/presentation/cubit/login_cubit.dart';
import 'package:daftariapp/features/auth/login/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/auth/sign_up/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/screens/register_screen.dart';
import 'package:daftariapp/features/auth/update_password/domain/usecases/update_password_usecase.dart';
import 'package:daftariapp/features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import 'package:daftariapp/features/auth/update_password/presentation/screens/update_password_screen.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/check_email_verified_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/resend_verification_email_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import 'package:daftariapp/features/auth/verify_email/presentation/screens/verify_email_screen.dart';
import 'package:daftariapp/features/auth/widgets/account_settings_section.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:daftariapp/features/settings/domain/repositories/settings_repository.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard_test_setup.dart';
import '../../security_test_setup.dart';
import 'auth_test_fakes.dart';

const _routeUserA = AuthUser(
  id: 'user-a',
  email: 'owner@shop.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

const _routeUserB = AuthUser(
  id: 'user-b',
  email: 'other@shop.com',
  shopName: 'Other Shop',
  emailVerified: true,
);

class _FakeRouteSettingsRepository implements SettingsRepository {
  String _localeCode = 'ar';

  @override
  String get localeCode => _localeCode;

  @override
  Future<void> setLocaleCode(String localeCode) async {
    _localeCode = localeCode;
  }
}

class _FakeRouteThemeStorage extends Fake implements LocalStorageService {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
  }
}

SettingsCubit _createRouteSettingsCubit() {
  final repo = _FakeRouteSettingsRepository();
  return SettingsCubit(
    GetSettingsUseCase(repo),
    ChangeLanguageUseCase(repo),
    ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
  );
}

ThemeSwitcherCubit _createRouteThemeSwitcherCubit() => ThemeSwitcherCubit(
  _FakeRouteThemeStorage(),
  ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
);

GoRouter _createAuthRouter(
  FakeAuthBackend backend,
  AuthSessionCubit session, {
  AppLockCubit? appLock,
  List<LoginCubit>? createdLoginCubits,
  List<SignUpCubit>? createdSignUpCubits,
  List<ForgotPasswordCubit>? createdForgotCubits,
  List<VerifyEmailCubit>? createdVerifyCubits,
  List<UpdatePasswordCubit>? createdUpdateCubits,
}) => AppRouter.create(
  appLock: appLock,
  authSessionCubit: session,
  createLoginCubit: () {
    final cubit = LoginCubit(SignInUseCase(backend, backend), session);
    createdLoginCubits?.add(cubit);
    return cubit;
  },
  createSignUpCubit: () {
    final cubit = SignUpCubit(SignUpUseCase(backend, backend), session);
    createdSignUpCubits?.add(cubit);
    return cubit;
  },
  createForgotPasswordCubit: () {
    final cubit = ForgotPasswordCubit(
      SendPasswordResetUseCase(backend),
      session,
    );
    createdForgotCubits?.add(cubit);
    return cubit;
  },
  createVerifyEmailCubit: () {
    final cubit = VerifyEmailCubit(
      ResendVerificationEmailUseCase(backend),
      CheckEmailVerifiedUseCase(backend, backend),
      session,
    );
    createdVerifyCubits?.add(cubit);
    return cubit;
  },
  createUpdatePasswordCubit: () {
    final cubit = UpdatePasswordCubit(UpdatePasswordUseCase(backend), session);
    createdUpdateCubits?.add(cubit);
    return cubit;
  },
);

Finder _routeFormField(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

Finder _routeDialogText(String text) => find.descendant(
  of: find.byType(AppFeedbackDialog),
  matching: find.text(text),
);

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  testWidgets(
    'auth routes open outside the navigation shell and dispose route-scoped cubits on exit',
    (tester) async {
      final backend = FakeAuthBackend();
      final session = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await session.close();
        await backend.dispose();
      });
      final loginCubits = <LoginCubit>[];
      final signUpCubits = <SignUpCubit>[];
      final forgotCubits = <ForgotPasswordCubit>[];
      final verifyCubits = <VerifyEmailCubit>[];
      final updateCubits = <UpdatePasswordCubit>[];
      final router = _createAuthRouter(
        backend,
        session,
        createdLoginCubits: loginCubits,
        createdSignUpCubits: signUpCubits,
        createdForgotCubits: forgotCubits,
        createdVerifyCubits: verifyCubits,
        createdUpdateCubits: updateCubits,
      );
      await tester.pumpWidget(
        DaftariApp(router: router, authSessionCubit: session),
      );
      await tester.pumpAndSettle();

      for (final entry in {
        AppRoutes.authLogin: LoginScreen,
        AppRoutes.authRegister: RegisterScreen,
        AppRoutes.authForgotPassword: ForgotPasswordScreen,
        AppRoutes.authVerifyEmail: VerifyEmailScreen,
        AppRoutes.authUpdatePassword: UpdatePasswordScreen,
      }.entries) {
        router.go(entry.key);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, entry.key);
        expect(find.byType(entry.value), findsOneWidget);
        expect(find.byKey(const ValueKey('navigation-0')), findsNothing);
      }

      router.go(AppRoutes.root);
      await tester.pumpAndSettle();

      expect(loginCubits, hasLength(1));
      expect(loginCubits.single.isClosed, isTrue);
      expect(signUpCubits, hasLength(1));
      expect(signUpCubits.single.isClosed, isTrue);
      expect(forgotCubits, hasLength(1));
      expect(forgotCubits.single.isClosed, isTrue);
      expect(verifyCubits, hasLength(1));
      expect(verifyCubits.single.isClosed, isTrue);
      expect(updateCubits, hasLength(1));
      expect(updateCubits.single.isClosed, isTrue);
      expect(session.isClosed, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets('login links navigate to register and password recovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.authLogin);
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(LoginScreen)).l10n;

    await tester.tap(find.widgetWithText(TextButton, l10n.authForgotPassword));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, l10n.authCreateAccount));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    final signInLink = find.widgetWithText(TextButton, l10n.authSignInLink);
    await tester.ensureVisible(signInLink);
    await tester.pumpAndSettle();
    await tester.tap(signInLink);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('PIN lock takes precedence over auth routes', (tester) async {
    final repository = TestSecurityRepository(pin: '2468');
    final lock = await testAppLock(repository: repository);
    final router = AppRouter.create(appLock: lock);
    await tester.pumpWidget(DaftariApp(router: router, appLockCubit: lock));
    await tester.pumpAndSettle();

    expect(find.byType(PinLockScreen), findsWidgets);

    router.go(AppRoutes.authLogin);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.lock);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(PinLockScreen), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
    await lock.close();
  });

  testWidgets(
    'password recovery waits for PIN unlock then opens update password screen',
    (tester) async {
      const recoveryUser = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop',
        emailVerified: true,
      );
      final backend = FakeAuthBackend(linkedUserId: recoveryUser.id);
      final session = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await session.close();
        await backend.dispose();
      });

      final securityRepo = TestSecurityRepository(pin: '2468');
      final lock = await testAppLock(repository: securityRepo);
      addTearDown(lock.close);
      final router = _createAuthRouter(backend, session, appLock: lock);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        DaftariApp(
          router: router,
          appLockCubit: lock,
          authSessionCubit: session,
        ),
      );
      await tester.pumpAndSettle();

      backend.events.add(const AuthSessionPasswordRecovery(recoveryUser));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.lock);
      expect(find.byType(PinLockScreen), findsWidgets);
      expect(find.byType(UpdatePasswordScreen), findsNothing);

      await lock.verify('2468');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.authUpdatePassword,
      );
      expect(find.byType(UpdatePasswordScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  group('P11-09 open confirmation prompt scoped to triggered account', () {
    for (final confirmPromptA in [true, false]) {
      testWidgets(
        '${confirmPromptA ? 'confirming' : 'cancelling'} A prompt after switching to B does not write owner or sign out B until B prompt is answered',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final backend = FakeAuthBackend();
          final session = await createInitializedSessionCubit(backend);
          addTearDown(() async {
            await session.close();
            await backend.dispose();
          });

          final router = _createAuthRouter(backend, session);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            DaftariApp(router: router, authSessionCubit: session),
          );
          await tester.pump(SplashScreen.displayDuration);
          await tester.pumpAndSettle();

          backend.currentUser = _routeUserA;
          backend.events.add(const AuthSessionSignedIn(_routeUserA));
          await tester.pumpAndSettle();

          final l10n = tester.element(find.byType(AlertDialog)).l10n;
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text(l10n.authLinkDialogTitle), findsOneWidget);

          backend.currentUser = _routeUserB;
          backend.events.add(const AuthSessionSignedIn(_routeUserB));
          await tester.pumpAndSettle();
          expect(session.state.status, AuthStatus.linkConfirmationRequired);
          expect(session.state.user, _routeUserB);
          expect(find.byType(AlertDialog), findsOneWidget);

          if (confirmPromptA) {
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  AppButton,
                  l10n.authLinkDialogConfirm,
                ),
              ),
            );
          } else {
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text(l10n.cancel),
              ),
            );
          }
          await tester.pumpAndSettle();

          expect(backend.linkLedgerCalls, 0);
          expect(backend.linkedUserId, isNull);
          expect(backend.signOutCalls, 0);
          expect(backend.currentUser, _routeUserB);
          expect(session.state.status, AuthStatus.linkConfirmationRequired);
          expect(session.state.user, _routeUserB);
          expect(find.byType(AlertDialog), findsOneWidget);

          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(
                AppButton,
                l10n.authLinkDialogConfirm,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(backend.linkLedgerCalls, 1);
          expect(backend.linkedUserId, _routeUserB.id);
          expect(session.state.status, AuthStatus.authenticated);
          expect(session.state.user, _routeUserB);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        },
      );
    }
  });

  group('P11-10 startup confirmation and mismatch feedback', () {
    testWidgets(
      'restored unlinked session prompts once after splash when PIN is disabled',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _routeUserA,
          hasLocalData: true,
        );
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final router = _createAuthRouter(backend, session);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(router: router, authSessionCubit: session),
        );
        await tester.pump();
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);

        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        final l10n = tester.element(find.byType(AlertDialog)).l10n;
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(
              AppButton,
              l10n.authLinkDialogConfirm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(backend.linkLedgerCalls, 1);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(session.state.status, AuthStatus.authenticated);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'restored unlinked session prompts once after PIN unlock when PIN is enabled',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _routeUserA,
          hasLocalData: true,
        );
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PinLockScreen), findsWidgets);
        expect(find.byType(AlertDialog), findsNothing);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        final l10n = tester.element(find.byType(AlertDialog)).l10n;
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(
              AppButton,
              l10n.authLinkDialogConfirm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(backend.linkLedgerCalls, 1);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(session.state.status, AuthStatus.authenticated);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'restored mismatched session shows localized message once after splash when PIN is disabled',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _routeUserB,
          linkedUserId: _routeUserA.id,
        );
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final router = _createAuthRouter(backend, session);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(router: router, authSessionCubit: session),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(Scaffold).first).l10n;
        expect(_routeDialogText(l10n.authErrorAccountMismatch), findsOneWidget);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(backend.currentUser, isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'restored mismatched session shows localized message once after PIN unlock when PIN is enabled',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _routeUserB,
          linkedUserId: _routeUserA.id,
        );
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PinLockScreen), findsWidgets);
        expect(find.byType(AppFeedbackDialog), findsNothing);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(Scaffold).first).l10n;
        expect(_routeDialogText(l10n.authErrorAccountMismatch), findsOneWidget);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(backend.currentUser, isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  group('P11-11 single confirmation dialog from pushed auth screens', () {
    testWidgets(
      'navigating from Settings to Login opens one dialog, makes one decision, and returns to Settings',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final backend = FakeAuthBackend()
          ..signInOverride = const Right(_routeUserA);
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final settingsCubit = _createRouteSettingsCubit();
        addTearDown(settingsCubit.close);
        final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
        addTearDown(themeSwitcherCubit.close);
        final lock = await testAppLock();
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
            settingsCubit: settingsCubit,
            themeSwitcherCubit: themeSwitcherCubit,
          ),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        router.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        final settingsL10n = tester
            .element(find.byType(AccountSettingsSection))
            .l10n;

        final signInButton = find.widgetWithText(
          AppButton,
          settingsL10n.authAccountSignIn,
        );
        await tester.ensureVisible(signInButton);
        await tester.pumpAndSettle();
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);

        await tester.enterText(
          _routeFormField('auth-login-email'),
          _routeUserA.email,
        );
        await tester.enterText(
          _routeFormField('auth-login-password'),
          'password1',
        );
        final submitButton = find.widgetWithText(
          AppButton,
          settingsL10n.authSignIn,
        );
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(
              AppButton,
              settingsL10n.authLinkDialogConfirm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(backend.linkLedgerCalls, 1);
        expect(backend.linkedUserId, _routeUserA.id);
        await tester.tap(find.widgetWithText(AppButton, settingsL10n.ok));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.text(settingsL10n.authAccountLinkedTitle), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'navigating from Settings to Register with verified session opens one dialog, makes one decision, and returns to Settings',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final backend = FakeAuthBackend()
          ..signUpOverride = const Right(_routeUserA);
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final settingsCubit = _createRouteSettingsCubit();
        addTearDown(settingsCubit.close);
        final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
        addTearDown(themeSwitcherCubit.close);
        final lock = await testAppLock();
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
            settingsCubit: settingsCubit,
            themeSwitcherCubit: themeSwitcherCubit,
          ),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        router.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        final settingsL10n = tester
            .element(find.byType(AccountSettingsSection))
            .l10n;

        final createButton = find.widgetWithText(
          AppButton,
          settingsL10n.authAccountCreate,
        );
        await tester.ensureVisible(createButton);
        await tester.pumpAndSettle();
        await tester.tap(createButton);
        await tester.pumpAndSettle();
        expect(find.byType(RegisterScreen), findsOneWidget);

        await tester.enterText(
          _routeFormField('auth-register-shop'),
          'Al-Amana Grocery',
        );
        await tester.enterText(
          _routeFormField('auth-register-email'),
          _routeUserA.email,
        );
        await tester.enterText(
          _routeFormField('auth-register-password'),
          'password1',
        );
        await tester.enterText(
          _routeFormField('auth-register-confirm'),
          'password1',
        );
        final submitButton = find.widgetWithText(
          AppButton,
          settingsL10n.authRegisterAction,
        );
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(
              AppButton,
              settingsL10n.authLinkDialogConfirm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(backend.linkLedgerCalls, 1);
        expect(backend.linkedUserId, _routeUserA.id);
        await tester.tap(find.widgetWithText(AppButton, settingsL10n.ok));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(RegisterScreen), findsNothing);
        expect(find.text(settingsL10n.authAccountLinkedTitle), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  testWidgets(
    'P11-12 pending owner lookup does not restore signed-in Settings UI after sign-out',
    (tester) async {
      final pendingLookup = Completer<Either<AppFailure, LedgerLinkStatus>>();
      final backend = FakeAuthBackend(linkedUserId: _routeUserA.id)
        ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
      final session = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await session.close();
        await backend.dispose();
      });

      final settingsCubit = _createRouteSettingsCubit();
      addTearDown(settingsCubit.close);
      final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
      addTearDown(themeSwitcherCubit.close);
      final lock = await testAppLock();
      addTearDown(lock.close);
      final router = _createAuthRouter(backend, session, appLock: lock);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        DaftariApp(
          router: router,
          appLockCubit: lock,
          authSessionCubit: session,
          settingsCubit: settingsCubit,
          themeSwitcherCubit: themeSwitcherCubit,
        ),
      );
      await tester.pump(SplashScreen.displayDuration);
      await tester.pumpAndSettle();

      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

      backend.currentUser = _routeUserA;
      backend.events.add(const AuthSessionSignedIn(_routeUserA));
      await tester.pump();

      backend.currentUser = null;
      backend.events.add(const AuthSessionSignedOut());
      await tester.pumpAndSettle();

      pendingLookup.complete(const Right(LedgerLinkStatus.linkedToCurrentUser));
      await tester.pumpAndSettle();

      expect(session.state.status, AuthStatus.unauthenticated);
      expect(session.state.user, isNull);
      expect(find.text(l10n.authAccountSignedOutTitle), findsOneWidget);
      expect(find.text(l10n.authAccountLinkedTitle), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  group('P11-13 password recovery mismatch and cancellation', () {
    testWidgets(
      'recovery event for B on A ledger signs B out, preserves A, and shows isolation message after PIN unlock',
      (tester) async {
        final backend = FakeAuthBackend(linkedUserId: _routeUserA.id);
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
          ),
        );
        await tester.pumpAndSettle();

        backend.currentUser = _routeUserB;
        backend.events.add(const AuthSessionPasswordRecovery(_routeUserB));
        await tester.pumpAndSettle();

        expect(backend.currentUser, isNull);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(session.state.passwordRecoveryPending, isFalse);
        expect(find.byType(PinLockScreen), findsWidgets);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        expect(find.byType(UpdatePasswordScreen), findsNothing);
        final l10n = tester.element(find.byType(Scaffold).first).l10n;
        expect(_routeDialogText(l10n.authErrorAccountMismatch), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'cancelling recovery for matching account signs out provider and remains signed out after restart',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final backend = FakeAuthBackend(linkedUserId: _routeUserA.id);
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final router = _createAuthRouter(backend, session);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(router: router, authSessionCubit: session),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        backend.currentUser = _routeUserA;
        backend.events.add(const AuthSessionPasswordRecovery(_routeUserA));
        await tester.pumpAndSettle();
        expect(find.byType(UpdatePasswordScreen), findsOneWidget);

        final l10n = tester.element(find.byType(UpdatePasswordScreen)).l10n;
        final backButton = find.widgetWithText(
          TextButton,
          l10n.authBackToLogin,
        );
        await tester.ensureVisible(backButton);
        await tester.pumpAndSettle();
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(backend.currentUser, isNull);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(session.state.status, AuthStatus.unauthenticated);

        final restartedSession = await createInitializedSessionCubit(backend);
        addTearDown(restartedSession.close);
        final restartedSettingsCubit = _createRouteSettingsCubit();
        addTearDown(restartedSettingsCubit.close);
        final restartedThemeSwitcherCubit = _createRouteThemeSwitcherCubit();
        addTearDown(restartedThemeSwitcherCubit.close);
        final restartedLock = await testAppLock();
        addTearDown(restartedLock.close);
        final restartedRouter = _createAuthRouter(
          backend,
          restartedSession,
          appLock: restartedLock,
        );
        addTearDown(restartedRouter.dispose);

        await tester.pumpWidget(
          DaftariApp(
            router: restartedRouter,
            appLockCubit: restartedLock,
            authSessionCubit: restartedSession,
            settingsCubit: restartedSettingsCubit,
            themeSwitcherCubit: restartedThemeSwitcherCubit,
          ),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        restartedRouter.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        final settingsL10n = tester
            .element(find.byType(AccountSettingsSection))
            .l10n;

        expect(backend.currentUser, isNull);
        expect(restartedSession.state.status, AuthStatus.unauthenticated);
        expect(
          find.text(settingsL10n.authAccountSignedOutTitle),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  group('P11-12 explicit sign-in interrupted by provider session changes', () {
    testWidgets(
      'sign-out during LoginCubit signIn lookup keeps session and Settings signed out',
      (tester) async {
        final pendingLookup = Completer<Either<AppFailure, LedgerLinkStatus>>();
        final backend = FakeAuthBackend(linkedUserId: _routeUserA.id)
          ..signInOverride = const Right(_routeUserA)
          ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
        final session = await createInitializedSessionCubit(backend);
        final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
        addTearDown(() async {
          await loginCubit.close();
          await session.close();
          await backend.dispose();
        });

        final settingsCubit = _createRouteSettingsCubit();
        addTearDown(settingsCubit.close);
        final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
        addTearDown(themeSwitcherCubit.close);
        final lock = await testAppLock();
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
            settingsCubit: settingsCubit,
            themeSwitcherCubit: themeSwitcherCubit,
          ),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        router.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

        final signInFuture = loginCubit.signIn(
          email: _routeUserA.email,
          password: 'password1',
        );
        await tester.pump();

        backend.currentUser = null;
        backend.events.add(const AuthSessionSignedOut());
        await tester.pumpAndSettle();

        pendingLookup.complete(
          const Right(LedgerLinkStatus.linkedToCurrentUser),
        );
        await signInFuture;
        await tester.pumpAndSettle();

        expect(session.state.status, AuthStatus.unauthenticated);
        expect(session.state.user, isNull);
        expect(find.text(l10n.authAccountSignedOutTitle), findsOneWidget);
        expect(find.text(l10n.authAccountLinkedTitle), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'replacement user B during LoginCubit signIn for A prevents A from replacing B in session and Settings',
      (tester) async {
        final pendingLookupA =
            Completer<Either<AppFailure, LedgerLinkStatus>>();
        final backend = FakeAuthBackend(linkedUserId: _routeUserB.id)
          ..signInOverride = const Right(_routeUserA)
          ..onGetLedgerLinkStatus = (userId) async {
            if (userId == _routeUserA.id) return pendingLookupA.future;
            return const Right(LedgerLinkStatus.linkedToCurrentUser);
          };
        final session = await createInitializedSessionCubit(backend);
        final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
        addTearDown(() async {
          await loginCubit.close();
          await session.close();
          await backend.dispose();
        });

        final settingsCubit = _createRouteSettingsCubit();
        addTearDown(settingsCubit.close);
        final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
        addTearDown(themeSwitcherCubit.close);
        final lock = await testAppLock();
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
            settingsCubit: settingsCubit,
            themeSwitcherCubit: themeSwitcherCubit,
          ),
        );
        await tester.pump(SplashScreen.displayDuration);
        await tester.pumpAndSettle();

        router.go(AppRoutes.settings);
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

        final signInFuture = loginCubit.signIn(
          email: _routeUserA.email,
          password: 'password1',
        );
        await tester.pump();

        backend.currentUser = _routeUserB;
        backend.events.add(const AuthSessionSignedIn(_routeUserB));
        await tester.pumpAndSettle();

        pendingLookupA.complete(
          const Right(LedgerLinkStatus.linkedToCurrentUser),
        );
        await signInFuture;
        await tester.pumpAndSettle();

        expect(session.state.status, AuthStatus.authenticated);
        expect(session.state.user, _routeUserB);
        expect(
          find.text(l10n.authAccountLinkedTo(_routeUserB.email)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.authAccountLinkedTo(_routeUserA.email)),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  group('P11-14 mismatch isolation message when signOut emits signed-out', () {
    testWidgets(
      'startup mismatch with PIN enabled still shows isolation message once after unlock',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _routeUserB,
          linkedUserId: _routeUserA.id,
        )..emitSignedOutEvent = true;
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PinLockScreen), findsWidgets);
        expect(find.byType(AppFeedbackDialog), findsNothing);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(Scaffold).first).l10n;
        expect(_routeDialogText(l10n.authErrorAccountMismatch), findsOneWidget);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(backend.currentUser, isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'passive mismatched sign-in while PIN-locked shows isolation message once after unlock',
      (tester) async {
        final backend = FakeAuthBackend(linkedUserId: _routeUserA.id)
          ..emitSignedOutEvent = true;
        final session = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await session.close();
          await backend.dispose();
        });

        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        addTearDown(lock.close);
        final router = _createAuthRouter(backend, session, appLock: lock);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          DaftariApp(
            router: router,
            appLockCubit: lock,
            authSessionCubit: session,
          ),
        );
        await tester.pumpAndSettle();

        backend.currentUser = _routeUserB;
        backend.events.add(const AuthSessionSignedIn(_routeUserB));
        await tester.pumpAndSettle();

        expect(backend.linkedUserId, _routeUserA.id);
        expect(backend.currentUser, isNull);
        expect(find.byType(PinLockScreen), findsWidgets);
        expect(find.byType(AppFeedbackDialog), findsNothing);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        final l10n = tester.element(find.byType(Scaffold).first).l10n;
        expect(_routeDialogText(l10n.authErrorAccountMismatch), findsOneWidget);
        expect(backend.linkedUserId, _routeUserA.id);
        expect(backend.currentUser, isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  group('P11-15 closing auth route preserves pending session outcome', () {
    for (final linked in [true, false]) {
      testWidgets(
        'popping Login while owner lookup is pending on ${linked ? 'linked' : 'unlinked'} ledger still applies session outcome',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final pendingLookup =
              Completer<Either<AppFailure, LedgerLinkStatus>>();
          final backend =
              FakeAuthBackend(linkedUserId: linked ? _routeUserA.id : null)
                ..signInOverride = const Right(_routeUserA)
                ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
          final session = await createInitializedSessionCubit(backend);
          addTearDown(() async {
            await session.close();
            await backend.dispose();
          });

          final settingsCubit = _createRouteSettingsCubit();
          addTearDown(settingsCubit.close);
          final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
          addTearDown(themeSwitcherCubit.close);
          final lock = await testAppLock();
          addTearDown(lock.close);
          final createdLoginCubits = <LoginCubit>[];
          final router = _createAuthRouter(
            backend,
            session,
            appLock: lock,
            createdLoginCubits: createdLoginCubits,
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            DaftariApp(
              router: router,
              appLockCubit: lock,
              authSessionCubit: session,
              settingsCubit: settingsCubit,
              themeSwitcherCubit: themeSwitcherCubit,
            ),
          );
          await tester.pump(SplashScreen.displayDuration);
          await tester.pumpAndSettle();

          router.go(AppRoutes.settings);
          await tester.pumpAndSettle();
          final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

          final signInButton = find.widgetWithText(
            AppButton,
            l10n.authAccountSignIn,
          );
          await tester.ensureVisible(signInButton);
          await tester.pumpAndSettle();
          await tester.tap(signInButton);
          await tester.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);

          await tester.enterText(
            _routeFormField('auth-login-email'),
            _routeUserA.email,
          );
          await tester.enterText(
            _routeFormField('auth-login-password'),
            'password1',
          );
          final submitButton = find.widgetWithText(AppButton, l10n.authSignIn);
          await tester.ensureVisible(submitButton);
          await tester.pumpAndSettle();
          await tester.tap(submitButton);
          await tester.pump();

          // Provider emits matching sign-in while owner lookup is still held.
          backend.events.add(const AuthSessionSignedIn(_routeUserA));
          await tester.pump();

          // Pop Login route before lookup completes; route-scoped cubit closes.
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(createdLoginCubits.single.isClosed, isTrue);

          pendingLookup.complete(
            Right(
              linked
                  ? LedgerLinkStatus.linkedToCurrentUser
                  : LedgerLinkStatus.unlinked,
            ),
          );
          await tester.pumpAndSettle();

          if (linked) {
            expect(session.state.status, AuthStatus.authenticated);
            expect(session.state.user, _routeUserA);
            expect(find.text(l10n.authAccountLinkedTitle), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
          } else {
            expect(session.state.status, AuthStatus.linkConfirmationRequired);
            expect(session.state.user, _routeUserA);
            expect(find.byType(AlertDialog), findsOneWidget);
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  AppButton,
                  l10n.authLinkDialogConfirm,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(backend.linkLedgerCalls, 1);
            expect(backend.linkedUserId, _routeUserA.id);
            expect(session.state.status, AuthStatus.authenticated);
            expect(
              _routeDialogText(l10n.authAccountLinkedTitle),
              findsOneWidget,
            );
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        },
      );

      testWidgets(
        'popping Register with verified sign-up while owner lookup is pending on ${linked ? 'linked' : 'unlinked'} ledger still applies session outcome',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final pendingLookup =
              Completer<Either<AppFailure, LedgerLinkStatus>>();
          final backend =
              FakeAuthBackend(linkedUserId: linked ? _routeUserA.id : null)
                ..signUpOverride = const Right(_routeUserA)
                ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
          final session = await createInitializedSessionCubit(backend);
          addTearDown(() async {
            await session.close();
            await backend.dispose();
          });

          final settingsCubit = _createRouteSettingsCubit();
          addTearDown(settingsCubit.close);
          final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
          addTearDown(themeSwitcherCubit.close);
          final lock = await testAppLock();
          addTearDown(lock.close);
          final createdSignUpCubits = <SignUpCubit>[];
          final router = _createAuthRouter(
            backend,
            session,
            appLock: lock,
            createdSignUpCubits: createdSignUpCubits,
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            DaftariApp(
              router: router,
              appLockCubit: lock,
              authSessionCubit: session,
              settingsCubit: settingsCubit,
              themeSwitcherCubit: themeSwitcherCubit,
            ),
          );
          await tester.pump(SplashScreen.displayDuration);
          await tester.pumpAndSettle();

          router.go(AppRoutes.settings);
          await tester.pumpAndSettle();
          final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

          final createButton = find.widgetWithText(
            AppButton,
            l10n.authAccountCreate,
          );
          await tester.ensureVisible(createButton);
          await tester.pumpAndSettle();
          await tester.tap(createButton);
          await tester.pumpAndSettle();
          expect(find.byType(RegisterScreen), findsOneWidget);

          await tester.enterText(
            _routeFormField('auth-register-shop'),
            'Al-Amana Grocery',
          );
          await tester.enterText(
            _routeFormField('auth-register-email'),
            _routeUserA.email,
          );
          await tester.enterText(
            _routeFormField('auth-register-password'),
            'password1',
          );
          await tester.enterText(
            _routeFormField('auth-register-confirm'),
            'password1',
          );
          final submitButton = find.widgetWithText(
            AppButton,
            l10n.authRegisterAction,
          );
          await tester.ensureVisible(submitButton);
          await tester.pumpAndSettle();
          await tester.tap(submitButton);
          await tester.pump();

          backend.events.add(const AuthSessionSignedIn(_routeUserA));
          await tester.pump();

          router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(createdSignUpCubits.single.isClosed, isTrue);

          pendingLookup.complete(
            Right(
              linked
                  ? LedgerLinkStatus.linkedToCurrentUser
                  : LedgerLinkStatus.unlinked,
            ),
          );
          await tester.pumpAndSettle();

          if (linked) {
            expect(session.state.status, AuthStatus.authenticated);
            expect(session.state.user, _routeUserA);
            expect(find.text(l10n.authAccountLinkedTitle), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
          } else {
            expect(session.state.status, AuthStatus.linkConfirmationRequired);
            expect(session.state.user, _routeUserA);
            expect(find.byType(AlertDialog), findsOneWidget);
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  AppButton,
                  l10n.authLinkDialogConfirm,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(backend.linkLedgerCalls, 1);
            expect(backend.linkedUserId, _routeUserA.id);
            expect(session.state.status, AuthStatus.authenticated);
            expect(
              _routeDialogText(l10n.authAccountLinkedTitle),
              findsOneWidget,
            );
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        },
      );

      testWidgets(
        'popping VerifyEmail while verification check lookup is pending on ${linked ? 'linked' : 'unlinked'} ledger still applies session outcome',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final pendingLookup =
              Completer<Either<AppFailure, LedgerLinkStatus>>();
          final backend = FakeAuthBackend(
            linkedUserId: linked ? _routeUserA.id : null,
          )..onGetLedgerLinkStatus = (_) => pendingLookup.future;
          final session = await createInitializedSessionCubit(backend);
          addTearDown(() async {
            await session.close();
            await backend.dispose();
          });

          final settingsCubit = _createRouteSettingsCubit();
          addTearDown(settingsCubit.close);
          final themeSwitcherCubit = _createRouteThemeSwitcherCubit();
          addTearDown(themeSwitcherCubit.close);
          final lock = await testAppLock();
          addTearDown(lock.close);
          final createdVerifyCubits = <VerifyEmailCubit>[];
          final router = _createAuthRouter(
            backend,
            session,
            appLock: lock,
            createdVerifyCubits: createdVerifyCubits,
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            DaftariApp(
              router: router,
              appLockCubit: lock,
              authSessionCubit: session,
              settingsCubit: settingsCubit,
              themeSwitcherCubit: themeSwitcherCubit,
            ),
          );
          await tester.pump(SplashScreen.displayDuration);
          await tester.pumpAndSettle();

          router.go(AppRoutes.settings);
          await tester.pumpAndSettle();
          final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

          unawaited(
            router.push(
              '${AppRoutes.authVerifyEmail}?email=${Uri.encodeQueryComponent(_routeUserA.email)}',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(VerifyEmailScreen), findsOneWidget);

          backend.currentUser = _routeUserA;
          final verifyButton = find.widgetWithText(
            AppButton,
            l10n.authVerifiedAction,
          );
          await tester.ensureVisible(verifyButton);
          await tester.pumpAndSettle();
          await tester.tap(verifyButton);
          await tester.pump();

          backend.events.add(const AuthSessionSignedIn(_routeUserA));
          await tester.pump();

          router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(createdVerifyCubits.single.isClosed, isTrue);

          pendingLookup.complete(
            Right(
              linked
                  ? LedgerLinkStatus.linkedToCurrentUser
                  : LedgerLinkStatus.unlinked,
            ),
          );
          await tester.pumpAndSettle();

          if (linked) {
            expect(session.state.status, AuthStatus.authenticated);
            expect(session.state.user, _routeUserA);
            expect(find.text(l10n.authAccountLinkedTitle), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
          } else {
            expect(session.state.status, AuthStatus.linkConfirmationRequired);
            expect(session.state.user, _routeUserA);
            expect(find.byType(AlertDialog), findsOneWidget);
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  AppButton,
                  l10n.authLinkDialogConfirm,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(backend.linkLedgerCalls, 1);
            expect(backend.linkedUserId, _routeUserA.id);
            expect(session.state.status, AuthStatus.authenticated);
            expect(
              _routeDialogText(l10n.authAccountLinkedTitle),
              findsOneWidget,
            );
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        },
      );
    }
  });
}
