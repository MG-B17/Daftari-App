import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/validators.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/register_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/update_password_screen.dart';
import 'package:daftariapp/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:daftariapp/features/auth/presentation/widgets/account_settings_section.dart';
import 'package:daftariapp/features/auth/presentation/widgets/ledger_link_confirmation_dialog.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  String locale = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
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
    ),
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
  testWidgets('login renders RTL Arabic content and validates fields', (
    tester,
  ) async {
    await _pump(tester, const LoginScreen());
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

    await tester.enterText(_formField('auth-login-email'), 'shop@example.com');
    await tester.enterText(_formField('auth-login-password'), 'password1');
    await _tapButton(tester, l10n.authSignIn);

    expect(_snackBarText(l10n.authLoginMockNotice), findsOneWidget);
  });

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

  testWidgets('register submits with mock feedback when valid', (tester) async {
    await _pump(tester, const RegisterScreen());
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

    expect(_snackBarText(l10n.authRegisterMockNotice), findsOneWidget);
  });

  testWidgets('forgot password moves to the sent confirmation state', (
    tester,
  ) async {
    await _pump(tester, const ForgotPasswordScreen());
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

  testWidgets('verify email shows the address and mock feedback', (
    tester,
  ) async {
    await _pump(tester, const VerifyEmailScreen(email: 'shop@example.com'));
    final l10n = tester.element(find.byType(VerifyEmailScreen)).l10n;

    expect(find.text('shop@example.com'), findsOneWidget);
    expect(
      find.text(l10n.authVerifySubtitle('shop@example.com')),
      findsOneWidget,
    );

    await _tapButton(tester, l10n.authResendVerification);
    expect(_snackBarText(l10n.authResendSent), findsOneWidget);

    await _tapButton(tester, l10n.authVerifiedAction);
    expect(_snackBarText(l10n.authVerifyMockNotice), findsOneWidget);
  });

  testWidgets('update password validates the confirmation', (tester) async {
    await _pump(tester, const UpdatePasswordScreen());
    final l10n = tester.element(find.byType(UpdatePasswordScreen)).l10n;

    await tester.enterText(_formField('auth-update-password'), 'password1');
    await tester.enterText(_formField('auth-update-confirm'), 'password2');
    await _tapButton(tester, l10n.authUpdatePasswordAction);

    expect(find.text(l10n.authPasswordMismatch), findsOneWidget);
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
    await _pump(tester, const Scaffold(body: AccountSettingsSection()));
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

    await _pump(
      tester,
      const Scaffold(
        body: AccountSettingsSection(
          mockEmail: 'shop@example.com',
          mockShopName: 'Al-Amana Grocery',
          mockEmailVerified: true,
        ),
      ),
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
    await _pump(
      tester,
      const Scaffold(
        body: AccountSettingsSection(mockEmail: 'shop@example.com'),
      ),
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

    expect(_snackBarText(l10n.authAccountMockNotice), findsOneWidget);
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
