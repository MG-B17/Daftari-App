import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/utils/validators.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_outcome.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/auth/sign_up/data/repositories/sign_up_repository_impl.dart';
import 'package:daftariapp/features/auth/sign_up/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/screens/register_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth_test_fakes.dart';

void main() {
  group('SignUpRepositoryImpl', () {
    test('delegates signUpWithPassword and maps provider errors', () async {
      final authService = FakeAuthService();
      final errorMapper = AuthErrorMapper(
        ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
      );
      final repository = SignUpRepositoryImpl(authService, errorMapper);

      expect(
        await repository.signUpWithPassword(
          email: 'owner@shop.com',
          password: 'password1',
          shopName: 'Shop',
        ),
        Right<AppFailure, AuthUser>(authService.signInUser),
      );

      authService.errorToThrow = const sb.AuthException('Signup failed');
      expect(
        await repository.signUpWithPassword(
          email: 'owner@shop.com',
          password: 'password1',
          shopName: 'Shop',
        ),
        const Left<AppFailure, AuthUser>(AppFailure(AppErrorCode.auth)),
      );
    });
  });

  group('SignUpUseCase', () {
    late FakeAuthBackend backend;

    setUp(() => backend = FakeAuthBackend(currentUser: testUserA));
    tearDown(() => backend.dispose());

    for (final invalid in [
      ('owner@shop.com', 'password1', ''),
      ('owner@shop.com', 'password1', '   '),
      ('invalid-email', 'password1', 'Shop'),
      ('owner@shop.com', '1234567', 'Shop'),
    ]) {
      test('rejects invalid input $invalid without calling repo', () async {
        final result = await SignUpUseCase(backend, backend)(
          email: invalid.$1,
          password: invalid.$2,
          shopName: invalid.$3,
        );
        expect(
          result,
          const Left<AppFailure, AuthOutcome>(testValidationFailure),
        );
        expect(backend.signUpCalls, 0);
      });
    }

    test('trims email and shopName, preserves password, and returns emailVerificationRequired', () async {
      final result = await SignUpUseCase(backend, backend)(
        email: '  pending@shop.com ',
        password: ' password1 ',
        shopName: '  Al-Amana Grocery  ',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(
          AuthEmailVerificationRequired(email: 'pending@shop.com'),
        ),
      );
      expect(backend.lastArgs, (
        'pending@shop.com',
        ' password1 ',
        'Al-Amana Grocery',
      ));
      expect(backend.linkLedgerCalls, 0);
    });

    test('enforces link confirmation when signUp returns verified user on unlinked ledger', () async {
      backend.signUpOverride = const Right(testUserA);
      final result = await SignUpUseCase(backend, backend)(
        email: 'owner@shop.com',
        password: 'password1',
        shopName: 'Al-Amana Grocery',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: testUserA, hasLocalData: true),
        ),
      );
      expect(backend.linkedUserId, isNull);
    });

    test('blocks mismatched account when signUp returns verified user for another owner', () async {
      backend.linkedUserId = testUserA.id;
      backend.signUpOverride = const Right(testUserB);
      final result = await SignUpUseCase(backend, backend)(
        email: 'other@shop.com',
        password: 'password1',
        shopName: 'Other Shop',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(backend.signOutCalls, 1);
      expect(backend.linkedUserId, testUserA.id);
    });
  });

  group('SignUpCubit and RegisterScreen', () {
    test(
      'SignUpCubit transitions session to emailVerificationRequired',
      () async {
        final backend = FakeAuthBackend();
        final session = await createInitializedSessionCubit(backend);
        final signUpCubit = SignUpCubit(
          SignUpUseCase(backend, backend),
          session,
        );
        addTearDown(() async {
          await signUpCubit.close();
          await session.close();
          await backend.dispose();
        });

        await signUpCubit.signUp(
          email: testUnverifiedUser.email,
          password: 'password1',
          shopName: 'Pending Shop',
        );

        expect(session.state.status, AuthStatus.emailVerificationRequired);
        expect(session.state.pendingEmail, testUnverifiedUser.email);
      },
    );

    testWidgets('register validates required fields and confirmation', (
      tester,
    ) async {
      await pumpAuthScreen(tester, const RegisterScreen());
      final context = tester.element(find.byType(RegisterScreen));
      final l10n = context.l10n;

      expect(find.text(l10n.authShopNameViewerHint), findsOneWidget);
      expect(find.textContaining('${l10n.authShopName} *'), findsOneWidget);
      await tapAuthButton(tester, l10n.authRegisterAction);

      expect(find.text(l10n.authShopNameRequired), findsOneWidget);
      expect(find.text(Validators.email('', locale: 'ar')!), findsOneWidget);
      expect(find.text(Validators.password('', locale: 'ar')!), findsOneWidget);

      await tester.enterText(
        authFormField('auth-register-shop'),
        'Al-Amana Grocery',
      );
      await tester.enterText(
        authFormField('auth-register-email'),
        'shop@example.com',
      );
      await tester.enterText(
        authFormField('auth-register-password'),
        'password1',
      );
      await tester.enterText(
        authFormField('auth-register-confirm'),
        'password2',
      );
      await tapAuthButton(tester, l10n.authRegisterAction);

      expect(find.text(l10n.authPasswordMismatch), findsOneWidget);
    });

    testWidgets('register submits through SignUpCubit to AuthSessionCubit', (
      tester,
    ) async {
      final backend = FakeAuthBackend();
      final session = await createInitializedSessionCubit(backend);
      final signUpCubit = SignUpCubit(SignUpUseCase(backend, backend), session);
      addTearDown(() async {
        await signUpCubit.close();
        await session.close();
        await backend.dispose();
      });

      await pumpAuthScreen(
        tester,
        const RegisterScreen(),
        providers: [
          BlocProvider<AuthSessionCubit>.value(value: session),
          BlocProvider<SignUpCubit>.value(value: signUpCubit),
        ],
      );
      final l10n = tester.element(find.byType(RegisterScreen)).l10n;

      await tester.enterText(
        authFormField('auth-register-shop'),
        'Al-Amana Grocery',
      );
      await tester.enterText(
        authFormField('auth-register-email'),
        'shop@example.com',
      );
      await tester.enterText(
        authFormField('auth-register-password'),
        'password1',
      );
      await tester.enterText(
        authFormField('auth-register-confirm'),
        'password1',
      );
      await tapAuthButton(tester, l10n.authRegisterAction);

      expect(session.state.status, AuthStatus.emailVerificationRequired);
    });
  });
}
