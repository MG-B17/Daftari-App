import 'dart:io';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/forgot_password/data/repositories/forgot_password_repository_impl.dart';
import 'package:daftariapp/features/auth/forgot_password/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import 'package:daftariapp/features/auth/forgot_password/presentation/screens/forgot_password_screen.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../auth_test_fakes.dart';

void main() {
  group('ForgotPasswordRepositoryImpl', () {
    test('maps SocketException to network AppFailure', () async {
      final authService = FakeAuthService()
        ..errorToThrow = const SocketException('No internet');
      final errorMapper = AuthErrorMapper(
        ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
      );
      final repository = ForgotPasswordRepositoryImpl(authService, errorMapper);

      expect(
        await repository.sendPasswordResetEmail('owner@shop.com'),
        const Left<AppFailure, void>(AppFailure(AppErrorCode.network)),
      );
    });
  });

  group('SendPasswordResetUseCase', () {
    late FakeAuthBackend backend;

    setUp(() => backend = FakeAuthBackend());
    tearDown(() => backend.dispose());

    test('rejects invalid email without calling repository', () async {
      final result = await SendPasswordResetUseCase(backend)('not-an-email');
      expect(result, const Left<AppFailure, void>(testValidationFailure));
      expect(backend.resetCalls, 0);
    });

    test('trims email and forwards success or failure', () async {
      final ok = await SendPasswordResetUseCase(backend)('  owner@shop.com ');
      expect(ok.isRight(), isTrue);
      expect(backend.lastArgs, 'owner@shop.com');
      expect(backend.resetCalls, 1);

      backend.resetResult = const Left(testAuthFailure);
      final err = await SendPasswordResetUseCase(backend)('owner@shop.com');
      expect(err, const Left<AppFailure, void>(testAuthFailure));
    });
  });

  group('ForgotPasswordCubit and ForgotPasswordScreen', () {
    test(
      'sendPasswordReset returns true on success and false on error',
      () async {
        final backend = FakeAuthBackend();
        final session = await createInitializedSessionCubit(backend);
        final cubit = ForgotPasswordCubit(
          SendPasswordResetUseCase(backend),
          session,
        );
        addTearDown(() async {
          await cubit.close();
          await session.close();
          await backend.dispose();
        });

        expect(await cubit.sendPasswordReset(testUserA.email), isTrue);
        expect(cubit.state.sent, isTrue);
        expect(cubit.state.feedback, AuthFeedback.passwordResetSent);

        backend.resetResult = const Left(AppFailure(AppErrorCode.network));
        expect(await cubit.sendPasswordReset(testUserA.email), isFalse);
        expect(cubit.state.feedback, AuthFeedback.networkError);
      },
    );

    testWidgets('moves to the sent confirmation state', (tester) async {
      final backend = FakeAuthBackend();
      final session = await createInitializedSessionCubit(backend);
      final cubit = ForgotPasswordCubit(
        SendPasswordResetUseCase(backend),
        session,
      );
      addTearDown(() async {
        await cubit.close();
        await session.close();
        await backend.dispose();
      });

      await pumpAuthScreen(
        tester,
        const ForgotPasswordScreen(),
        providers: [
          BlocProvider<AuthSessionCubit>.value(value: session),
          BlocProvider<ForgotPasswordCubit>.value(value: cubit),
        ],
      );
      final l10n = tester.element(find.byType(ForgotPasswordScreen)).l10n;

      await tester.enterText(
        authFormField('auth-forgot-email'),
        'shop@example.com',
      );
      await tapAuthButton(tester, l10n.authSendResetLink);

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
  });
}
