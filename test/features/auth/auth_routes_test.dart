import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:daftariapp/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:daftariapp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/register_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/update_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:daftariapp/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dashboard_test_setup.dart';
import '../../security_test_setup.dart';
import 'presentation/auth_cubit_test.dart';

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  testWidgets('auth routes open outside the navigation shell', (tester) async {
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
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

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

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
      final authRepo = FakeCubitAuthRepository(linkedUserId: recoveryUser.id);
      final authCubit = AuthCubit(
        authRepo,
        SignInUseCase(authRepo),
        SignUpUseCase(authRepo),
        SignOutUseCase(authRepo),
        ConfirmLedgerLinkUseCase(authRepo),
        SendPasswordResetUseCase(authRepo),
        UpdatePasswordUseCase(authRepo),
      );
      addTearDown(() async {
        await authCubit.close();
        await authRepo.dispose();
      });
      await authCubit.initialize();

      final securityRepo = TestSecurityRepository(pin: '2468');
      final lock = await testAppLock(repository: securityRepo);
      addTearDown(lock.close);
      final router = AppRouter.create(appLock: lock, authCubit: authCubit);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        DaftariApp(router: router, appLockCubit: lock, authCubit: authCubit),
      );
      await tester.pumpAndSettle();

      // Recovery event arrives while PIN-locked: lock screen must stay active.
      authRepo.events.add(const AuthSessionPasswordRecovery(recoveryUser));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.lock);
      expect(find.byType(PinLockScreen), findsWidgets);
      expect(find.byType(UpdatePasswordScreen), findsNothing);

      // Unlock with PIN: router immediately navigates to update-password.
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
}
