import 'dart:async';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/utils/validators.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/login/data/repositories/login_repository_impl.dart';
import 'package:daftariapp/features/auth/login/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/login/presentation/cubit/login_cubit.dart';
import 'package:daftariapp/features/auth/login/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/session/data/repositories/auth_session_repository_impl.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_outcome.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth_test_fakes.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _screenUser = AuthUser(
  id: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

void main() {
  group('LoginRepositoryImpl', () {
    late _MockSecureStorage secureStorage;
    late FakeAuthService authService;
    late List<String> logOutput;
    late LoginRepositoryImpl loginRepository;
    late AuthSessionRepositoryImpl sessionRepository;

    setUp(() {
      secureStorage = _MockSecureStorage();
      authService = FakeAuthService();
      logOutput = <String>[];
      final errorMapper = AuthErrorMapper(
        ErrorHandler(
          AppLogger(output: logOutput.add, enableCrashReporting: false),
        ),
      );
      loginRepository = LoginRepositoryImpl(authService, errorMapper);
      sessionRepository = AuthSessionRepositoryImpl(
        authService,
        LedgerOwnerStorage(secureStorage),
        () async => false,
        errorMapper,
      );
    });

    test('preserves email_not_confirmed as verification-required while keeping invalid_credentials as auth failure', () async {
      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => null);

      final signIn = SignInUseCase(loginRepository, sessionRepository);

      authService.errorToThrow = const sb.AuthApiException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );
      final unconfirmed = await signIn(
        email: 'pending@shop.com',
        password: 'password1',
      );
      expect(
        unconfirmed,
        const Right<AppFailure, AuthOutcome>(
          AuthEmailVerificationRequired(email: 'pending@shop.com'),
        ),
      );

      authService.errorToThrow = const sb.AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      final invalid = await signIn(
        email: 'pending@shop.com',
        password: 'password1',
      );
      expect(
        invalid,
        const Left<AppFailure, AuthOutcome>(AppFailure(AppErrorCode.auth)),
      );

      verifyNever(
        () => secureStorage.write(
          key: LedgerOwnerStorage.ownerKey,
          value: any(named: 'value'),
        ),
      );
    });

    test('maps auth and retryable errors to privacy-safe AppFailure without logging PII', () async {
      const secretEmail = 'sensitive.owner@example.com';

      authService.errorToThrow = const sb.AuthException(
        'Invalid login credentials for $secretEmail',
      );
      expect(
        await loginRepository.signInWithPassword(
          email: secretEmail,
          password: 'password1',
        ),
        const Left<AppFailure, AuthUser>(AppFailure(AppErrorCode.auth)),
      );

      authService.errorToThrow = sb.AuthRetryableFetchException(
        message: 'Failed to reach host for $secretEmail',
      );
      expect(
        await loginRepository.signInWithPassword(
          email: secretEmail,
          password: 'password1',
        ),
        const Left<AppFailure, AuthUser>(AppFailure(AppErrorCode.network)),
      );

      for (final entry in logOutput) {
        expect(entry, isNot(contains(secretEmail)));
      }
    });
  });

  group('SignInUseCase', () {
    late FakeAuthBackend backend;

    setUp(() => backend = FakeAuthBackend(currentUser: testUserA));
    tearDown(() => backend.dispose());

    for (final invalid in [
      ('', 'secret123'),
      ('bad-email', 'secret123'),
      ('owner@shop.com', 'short'),
      ('owner@shop.com', '        '),
    ]) {
      test('rejects invalid input $invalid without calling repo', () async {
        final result = await SignInUseCase(backend, backend)(
          email: invalid.$1,
          password: invalid.$2,
        );
        expect(
          result,
          const Left<AppFailure, AuthOutcome>(testValidationFailure),
        );
        expect(backend.signInCalls, 0);
      });
    }

    test('trims email, preserves untrimmed password, and returns signedIn when linked to current user', () async {
      backend.linkedUserId = testUserA.id;
      final result = await SignInUseCase(backend, backend)(
        email: '  owner@shop.com  ',
        password: '  secret12  ',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthSignedIn(user: testUserA)),
      );
      expect(backend.lastArgs, ('owner@shop.com', '  secret12  '));
      expect(backend.signOutCalls, 0);
      expect(backend.linkLedgerCalls, 0);
    });

    test('requires deliberate confirmation on first link when unlinked (with and without local data)', () async {
      backend.hasLocalData = true;
      final withData = await SignInUseCase(backend, backend)(
        email: 'owner@shop.com',
        password: 'password1',
      );
      expect(
        withData,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: testUserA, hasLocalData: true),
        ),
      );
      expect(backend.linkedUserId, isNull);
      expect(backend.linkLedgerCalls, 0);

      backend.hasLocalData = false;
      final withoutData = await SignInUseCase(backend, backend)(
        email: 'owner@shop.com',
        password: 'password1',
      );
      expect(
        withoutData,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: testUserA, hasLocalData: false),
        ),
      );
      expect(backend.linkedUserId, isNull);
    });

    test('blocks mismatched account, signs out immediately, and preserves original linkedUserId', () async {
      backend.linkedUserId = testUserA.id;
      backend.signInOverride = const Right(testUserB);

      final result = await SignInUseCase(backend, backend)(
        email: 'other@shop.com',
        password: 'password1',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(backend.signOutCalls, 1);
      expect(backend.linkedUserId, testUserA.id);
      expect(backend.linkLedgerCalls, 0);
    });

    test('returns failure if mismatch signOut fails', () async {
      backend.linkedUserId = testUserA.id;
      backend.signInOverride = const Right(testUserB);
      backend.signOutResult = const Left(testAuthFailure);

      final result = await SignInUseCase(backend, backend)(
        email: 'other@shop.com',
        password: 'password1',
      );

      expect(result, const Left<AppFailure, AuthOutcome>(testAuthFailure));
      expect(backend.linkedUserId, testUserA.id);
    });

    test(
      'signs out and returns failure if link status or local data check fails',
      () async {
        backend.linkStatusOverride = const Left(testStorageFailure);
        final statusErr = await SignInUseCase(backend, backend)(
          email: 'owner@shop.com',
          password: 'password1',
        );
        expect(
          statusErr,
          const Left<AppFailure, AuthOutcome>(testStorageFailure),
        );
        expect(backend.signOutCalls, 1);

        backend.linkStatusOverride = null;
        backend.hasLocalDataOverride = const Left(testDatabaseFailure);
        final dbErr = await SignInUseCase(backend, backend)(
          email: 'owner@shop.com',
          password: 'password1',
        );
        expect(dbErr, const Left<AppFailure, AuthOutcome>(testDatabaseFailure));
        expect(backend.signOutCalls, 2);
      },
    );

    test(
      'returns emailVerificationRequired when user email is not verified',
      () async {
        backend.signInOverride = const Right(testUnverifiedUser);
        final result = await SignInUseCase(backend, backend)(
          email: 'pending@shop.com',
          password: 'password1',
        );

        expect(
          result,
          const Right<AppFailure, AuthOutcome>(
            AuthEmailVerificationRequired(email: 'pending@shop.com'),
          ),
        );
        expect(backend.linkLedgerCalls, 0);
      },
    );

    test('forwards repository auth failure', () async {
      backend.signInOverride = const Left(testAuthFailure);
      final result = await SignInUseCase(backend, backend)(
        email: 'owner@shop.com',
        password: 'password1',
      );

      expect(result, const Left<AppFailure, AuthOutcome>(testAuthFailure));
    });

    test('scoped evaluation cleanup preserves replacement account on mismatch and lookup failures', () async {
      backend.linkedUserId = testUserB.id;
      backend.signInOverride = const Right(testUserA);
      final statusStarted = Completer<void>();
      final releaseStatus = Completer<Either<AppFailure, LedgerLinkStatus>>();
      backend.onGetLedgerLinkStatus = (_) {
        if (!statusStarted.isCompleted) statusStarted.complete();
        return releaseStatus.future;
      };

      final mismatchSignIn = SignInUseCase(backend, backend)(
        email: testUserA.email,
        password: 'password1',
      );
      await statusStarted.future;
      backend.currentUser = testUserB;
      releaseStatus.complete(const Right(LedgerLinkStatus.linkedToOtherUser));

      expect(
        await mismatchSignIn,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(backend.signOutCalls, 0);
      expect(backend.currentUser, testUserB);
      expect(backend.linkedUserId, testUserB.id);

      final failureStarted = Completer<void>();
      final releaseFailure = Completer<Either<AppFailure, LedgerLinkStatus>>();
      backend.onGetLedgerLinkStatus = (_) {
        if (!failureStarted.isCompleted) failureStarted.complete();
        return releaseFailure.future;
      };

      final statusFailureSignIn = SignInUseCase(backend, backend)(
        email: testUserA.email,
        password: 'password1',
      );
      await failureStarted.future;
      backend.currentUser = testUserB;
      releaseFailure.complete(const Left(testStorageFailure));

      expect(
        await statusFailureSignIn,
        const Left<AppFailure, AuthOutcome>(testStorageFailure),
      );
      expect(backend.signOutCalls, 0);
      expect(backend.currentUser, testUserB);
      expect(backend.linkedUserId, testUserB.id);

      backend.onGetLedgerLinkStatus = null;
      backend.linkedUserId = null;
      final localDataStarted = Completer<void>();
      final releaseLocalData = Completer<Either<AppFailure, bool>>();
      backend.onHasLocalData = () {
        if (!localDataStarted.isCompleted) localDataStarted.complete();
        return releaseLocalData.future;
      };

      final localDataFailureSignIn = SignInUseCase(backend, backend)(
        email: testUserA.email,
        password: 'password1',
      );
      await localDataStarted.future;
      backend.currentUser = testUserB;
      releaseLocalData.complete(const Left(testDatabaseFailure));

      expect(
        await localDataFailureSignIn,
        const Left<AppFailure, AuthOutcome>(testDatabaseFailure),
      );
      expect(backend.signOutCalls, 0);
      expect(backend.currentUser, testUserB);
    });
  });

  group('LoginCubit', () {
    test('emits unconfigured feedback when signing in unconfigured', () async {
      final backend = FakeAuthBackend(isConfigured: false);
      final session = await createInitializedSessionCubit(backend);
      final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
      addTearDown(() async {
        await loginCubit.close();
        await session.close();
        await backend.dispose();
      });

      await loginCubit.signIn(email: testUserA.email, password: 'password1');
      expect(loginCubit.state.feedback, AuthFeedback.unconfigured);
      expect(session.state.status, AuthStatus.unauthenticated);
    });

    test('P11-12 explicit signIn allows own provider event but is invalidated by sign-out', () async {
      final pendingLookup = Completer<Either<AppFailure, LedgerLinkStatus>>();
      final backend = FakeAuthBackend(linkedUserId: testUserA.id)
        ..signInOverride = const Right(testUserA)
        ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
      final session = await createInitializedSessionCubit(backend);
      final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
      addTearDown(() async {
        await loginCubit.close();
        await session.close();
        await backend.dispose();
      });

      final signInFuture = loginCubit.signIn(
        email: testUserA.email,
        password: 'password1',
      );
      await Future<void>.delayed(Duration.zero);

      backend.events.add(const AuthSessionSignedIn(testUserA));
      await Future<void>.delayed(Duration.zero);

      backend.currentUser = null;
      backend.events.add(const AuthSessionSignedOut());
      await Future<void>.delayed(Duration.zero);

      pendingLookup.complete(const Right(LedgerLinkStatus.linkedToCurrentUser));
      await signInFuture;

      expect(session.state.status, AuthStatus.unauthenticated);
      expect(session.state.user, isNull);
      expect(loginCubit.state.busy, isFalse);
    });

    test('P11-12 explicit signIn for A cannot overwrite B outcome when B replaces A during lookup', () async {
      final pendingLookupA = Completer<Either<AppFailure, LedgerLinkStatus>>();
      final backend = FakeAuthBackend(linkedUserId: testUserB.id)
        ..signInOverride = const Right(testUserA)
        ..onGetLedgerLinkStatus = (userId) async {
          if (userId == testUserA.id) return pendingLookupA.future;
          return const Right(LedgerLinkStatus.linkedToCurrentUser);
        };
      final session = await createInitializedSessionCubit(backend);
      final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
      addTearDown(() async {
        await loginCubit.close();
        await session.close();
        await backend.dispose();
      });

      final signInFuture = loginCubit.signIn(
        email: testUserA.email,
        password: 'password1',
      );
      await Future<void>.delayed(Duration.zero);

      backend.currentUser = testUserB;
      backend.events.add(const AuthSessionSignedIn(testUserB));
      await Future<void>.delayed(Duration.zero);
      expect(session.state.status, AuthStatus.authenticated);
      expect(session.state.user, testUserB);

      pendingLookupA.complete(
        const Right(LedgerLinkStatus.linkedToCurrentUser),
      );
      await signInFuture;

      expect(session.state.status, AuthStatus.authenticated);
      expect(session.state.user, testUserB);
    });
  });

  group('LoginScreen', () {
    testWidgets(
      'renders RTL Arabic, validates fields, and prompts first-time ledger link confirmation',
      (tester) async {
        final backend = FakeAuthBackend()
          ..signInOverride = const Right(_screenUser);
        final session = await createInitializedSessionCubit(backend);
        final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
        addTearDown(() async {
          await loginCubit.close();
          await session.close();
          await backend.dispose();
        });

        await pumpAuthScreen(
          tester,
          const LoginScreen(),
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: session),
            BlocProvider<LoginCubit>.value(value: loginCubit),
          ],
        );
        final context = tester.element(find.byType(LoginScreen));
        final l10n = context.l10n;

        expect(Directionality.of(context), TextDirection.rtl);
        expect(find.text(l10n.authLoginHeading), findsOneWidget);
        expect(find.text(l10n.authLoginSubtitle), findsOneWidget);
        expect(find.textContaining(l10n.authEmail), findsOneWidget);
        expect(find.text(l10n.authForgotPassword), findsOneWidget);
        expect(find.text(l10n.authSecureBadge), findsOneWidget);
        expect(find.text(l10n.authOfflineNoteTitle), findsOneWidget);

        await tapAuthButton(tester, l10n.authSignIn);

        expect(find.text(Validators.email('', locale: 'ar')!), findsOneWidget);
        expect(
          find.text(Validators.password('', locale: 'ar')!),
          findsOneWidget,
        );

        await tester.enterText(
          authFormField('auth-login-email'),
          'shop@example.com',
        );
        await tester.enterText(
          authFormField('auth-login-password'),
          'password1',
        );
        await tapAuthButton(tester, l10n.authSignIn);

        expect(find.text(l10n.authLinkDialogTitle), findsOneWidget);
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

        expect(session.state.status, AuthStatus.authenticated);
        expect(backend.linkedUserId, _screenUser.id);
        expect(authSnackBarText(l10n.authLinkedSuccess), findsOneWidget);
      },
    );

    testWidgets('password visibility can be toggled', (tester) async {
      await pumpAuthScreen(tester, const LoginScreen());
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

    testWidgets('renders LTR English in dark mode', (tester) async {
      await pumpAuthScreen(
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
  });
}
