import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/validators.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:daftariapp/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:daftariapp/features/auth/presentation/cubit/auth_state.dart';
import 'package:daftariapp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/register_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/update_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:daftariapp/features/auth/presentation/widgets/account_settings_section.dart';
import 'package:daftariapp/features/auth/presentation/widgets/ledger_link_confirmation_dialog.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'presentation/auth_cubit_test.dart';

const _testUser = AuthUser(
  id: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

Future<AuthCubit> _createAuthCubit(FakeCubitAuthRepository repo) async {
  final cubit = AuthCubit(
    repo,
    SignInUseCase(repo),
    SignUpUseCase(repo),
    SignOutUseCase(repo),
    ConfirmLedgerLinkUseCase(repo),
    SendPasswordResetUseCase(repo),
    UpdatePasswordUseCase(repo),
  );
  await cubit.initialize();
  return cubit;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AuthCubit? authCubit,
  String locale = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppConstants.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: screen,
    ),
  );
  await tester.pumpWidget(
    authCubit == null ? app : BlocProvider.value(value: authCubit, child: app),
  );
  await tester.pumpAndSettle();
}

Finder _formField(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

Finder _snackBarText(String text) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(text));

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'login renders RTL Arabic, validates fields, and prompts first-time ledger link confirmation',
    (tester) async {
      final repo = FakeCubitAuthRepository()
        ..signInOverride = const Right(_testUser);
      final cubit = await _createAuthCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.dispose();
      });

      await _pump(tester, const LoginScreen(), authCubit: cubit);
      final context = tester.element(find.byType(LoginScreen));
      final l10n = context.l10n;

      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text(l10n.authLoginHeading), findsOneWidget);
      expect(find.text(l10n.authLoginSubtitle), findsOneWidget);
      expect(find.textContaining(l10n.authEmail), findsOneWidget);
      expect(find.text(l10n.authForgotPassword), findsOneWidget);
      expect(find.text(l10n.authSecureBadge), findsOneWidget);
      expect(find.text(l10n.authOfflineNoteTitle), findsOneWidget);

      await _tapButton(tester, l10n.authSignIn);

      expect(find.text(Validators.email('', locale: 'ar')!), findsOneWidget);
      expect(find.text(Validators.password('', locale: 'ar')!), findsOneWidget);

      await tester.enterText(
        _formField('auth-login-email'),
        'shop@example.com',
      );
      await tester.enterText(_formField('auth-login-password'), 'password1');
      await _tapButton(tester, l10n.authSignIn);

      expect(find.text(l10n.authLinkDialogTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(AppButton, l10n.authLinkDialogConfirm),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(repo.linkedUserId, _testUser.id);
      expect(_snackBarText(l10n.authLinkedSuccess), findsOneWidget);
    },
  );

  testWidgets('login password visibility can be toggled', (tester) async {
    await _pump(tester, const LoginScreen());
    final field = find.descendant(
      of: find.byKey(const ValueKey('auth-login-password')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).obscureText, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('auth-login-password')),
        matching: find.byIcon(Icons.visibility_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).obscureText, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('auth-login-password')),
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('register validates required fields and confirmation', (
    tester,
  ) async {
    await _pump(tester, const RegisterScreen());
    final context = tester.element(find.byType(RegisterScreen));
    final l10n = context.l10n;

    expect(find.text(l10n.authShopNameViewerHint), findsOneWidget);
    expect(find.textContaining('${l10n.authShopName} *'), findsOneWidget);
    await _tapButton(tester, l10n.authRegisterAction);

    expect(find.text(l10n.authShopNameRequired), findsOneWidget);
    expect(find.text(Validators.email('', locale: 'ar')!), findsOneWidget);
    expect(find.text(Validators.password('', locale: 'ar')!), findsOneWidget);

    await tester.enterText(
      _formField('auth-register-shop'),
      'Al-Amana Grocery',
    );
    await tester.enterText(
      _formField('auth-register-email'),
      'shop@example.com',
    );
    await tester.enterText(_formField('auth-register-password'), 'password1');
    await tester.enterText(_formField('auth-register-confirm'), 'password2');
    await _tapButton(tester, l10n.authRegisterAction);

    expect(find.text(l10n.authPasswordMismatch), findsOneWidget);
  });

  testWidgets('register submits to AuthCubit when valid', (tester) async {
    final repo = FakeCubitAuthRepository();
    final cubit = await _createAuthCubit(repo);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });

    await _pump(tester, const RegisterScreen(), authCubit: cubit);
    final l10n = tester.element(find.byType(RegisterScreen)).l10n;

    await tester.enterText(
      _formField('auth-register-shop'),
      'Al-Amana Grocery',
    );
    await tester.enterText(
      _formField('auth-register-email'),
      'shop@example.com',
    );
    await tester.enterText(_formField('auth-register-password'), 'password1');
    await tester.enterText(_formField('auth-register-confirm'), 'password1');
    await _tapButton(tester, l10n.authRegisterAction);

    expect(cubit.state.status, AuthStatus.emailVerificationRequired);
  });

  testWidgets('forgot password moves to the sent confirmation state', (
    tester,
  ) async {
    final repo = FakeCubitAuthRepository();
    final cubit = await _createAuthCubit(repo);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });

    await _pump(tester, const ForgotPasswordScreen(), authCubit: cubit);
    final l10n = tester.element(find.byType(ForgotPasswordScreen)).l10n;

    await tester.enterText(_formField('auth-forgot-email'), 'shop@example.com');
    await _tapButton(tester, l10n.authSendResetLink);

    expect(find.text(l10n.authResetSentTitle), findsOneWidget);
    expect(
      find.text(l10n.authResetSentMessage('shop@example.com')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, l10n.authBackToLogin),
      findsOneWidget,
    );
  });

  testWidgets('verify email resends link and checks verification status', (
    tester,
  ) async {
    final repo = FakeCubitAuthRepository();
    final cubit = await _createAuthCubit(repo);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });

    await _pump(
      tester,
      const VerifyEmailScreen(email: 'shop@example.com'),
      authCubit: cubit,
    );
    final l10n = tester.element(find.byType(VerifyEmailScreen)).l10n;

    expect(find.text('shop@example.com'), findsOneWidget);
    expect(
      find.text(l10n.authVerifySubtitle('shop@example.com')),
      findsOneWidget,
    );

    await _tapButton(tester, l10n.authResendVerification);
    expect(repo.resendCalls, 1);
    expect(_snackBarText(l10n.authResendSent), findsOneWidget);

    await _tapButton(tester, l10n.authVerifiedAction);
    expect(_snackBarText(l10n.authEmailNotVerifiedYet), findsOneWidget);
  });

  testWidgets('update password validates confirmation and updates password', (
    tester,
  ) async {
    final repo = FakeCubitAuthRepository(
      currentUser: _testUser,
      linkedUserId: _testUser.id,
    );
    final cubit = await _createAuthCubit(repo);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });

    await _pump(tester, const UpdatePasswordScreen(), authCubit: cubit);
    final l10n = tester.element(find.byType(UpdatePasswordScreen)).l10n;

    await tester.enterText(_formField('auth-update-password'), 'password1');
    await tester.enterText(_formField('auth-update-confirm'), 'password2');
    await _tapButton(tester, l10n.authUpdatePasswordAction);
    expect(find.text(l10n.authPasswordMismatch), findsOneWidget);

    await tester.enterText(_formField('auth-update-confirm'), 'password1');
    await _tapButton(tester, l10n.authUpdatePasswordAction);
    expect(_snackBarText(l10n.authPasswordUpdated), findsOneWidget);
  });

  testWidgets('login renders LTR English in dark mode', (tester) async {
    await _pump(
      tester,
      const LoginScreen(),
      locale: 'en',
      themeMode: ThemeMode.dark,
    );
    final context = tester.element(find.byType(LoginScreen));

    expect(Directionality.of(context), TextDirection.ltr);
    expect(context.theme.brightness, Brightness.dark);
    expect(find.text('Protect your data from loss'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('account section shows signed-out and signed-in states', (
    tester,
  ) async {
    final signedOutRepo = FakeCubitAuthRepository();
    final signedOutCubit = await _createAuthCubit(signedOutRepo);
    addTearDown(() async {
      await signedOutCubit.close();
      await signedOutRepo.dispose();
    });

    await _pump(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      authCubit: signedOutCubit,
    );
    final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

    expect(find.text(l10n.authAccountSignedOutTitle), findsOneWidget);
    expect(find.text(l10n.authAccountSignedOutDescription), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, l10n.authAccountSignIn),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, l10n.authAccountCreate),
      findsOneWidget,
    );

    final signedInRepo = FakeCubitAuthRepository(
      currentUser: _testUser,
      linkedUserId: _testUser.id,
    );
    final signedInCubit = await _createAuthCubit(signedInRepo);
    addTearDown(() async {
      await signedInCubit.close();
      await signedInRepo.dispose();
    });

    await _pump(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      authCubit: signedInCubit,
    );
    final signedInContext = tester.element(find.byType(AccountSettingsSection));
    final signedInL10n = signedInContext.l10n;

    expect(find.text(signedInL10n.authAccountLinkedTitle), findsOneWidget);
    expect(
      find.text(signedInL10n.authAccountLinkedTo('shop@example.com')),
      findsOneWidget,
    );
    expect(find.text('Al-Amana Grocery'), findsOneWidget);
    expect(find.text(signedInL10n.authAccountVerified), findsOneWidget);
    expect(find.text(signedInL10n.authAccountSignOut), findsOneWidget);
    expect(l10n.authAccountTitle, signedInL10n.authAccountTitle);
  });

  testWidgets('signing out asks for confirmation and preserves local data', (
    tester,
  ) async {
    final repo = FakeCubitAuthRepository(
      currentUser: _testUser,
      linkedUserId: _testUser.id,
    );
    final cubit = await _createAuthCubit(repo);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });

    await _pump(
      tester,
      const Scaffold(body: AccountSettingsSection()),
      authCubit: cubit,
    );
    final l10n = tester.element(find.byType(AccountSettingsSection)).l10n;

    await tester.tap(find.text(l10n.authAccountSignOut));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.authAccountSignOutMessage),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(AppButton, l10n.authAccountSignOut),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.signOutCalls, 1);
    expect(repo.linkedUserId, _testUser.id);
    expect(cubit.state.status, AuthStatus.unauthenticated);
    expect(_snackBarText(l10n.authSignedOutSuccess), findsOneWidget);
  });

  testWidgets('ledger link confirmation returns the user decision', (
    tester,
  ) async {
    bool? decision;
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: 'open',
              onPressed: () async {
                decision = await LedgerLinkConfirmationDialog.show(context);
              },
            ),
          ),
        ),
      ),
    );
    final l10n = tester.element(find.text('open')).l10n;

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.authLinkDialogTitle), findsOneWidget);
    expect(find.text(l10n.authLinkDialogMessage), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(decision, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(AppButton, l10n.authLinkDialogConfirm),
      ),
    );
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });
}
