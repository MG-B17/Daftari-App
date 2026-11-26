import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/auth/verify_email/data/repositories/verify_email_repository_impl.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/check_email_verified_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/resend_verification_email_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import 'package:daftariapp/features/auth/verify_email/presentation/screens/verify_email_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth_test_fakes.dart';

void main() {
  group('VerifyEmailRepositoryImpl', () {
    test('delegates resend and getCurrentUser and maps errors', () async {
      final authService = FakeAuthService()..currentUser = testUserA;
      final errorMapper = AuthErrorMapper(
        ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
      );
      final repository = VerifyEmailRepositoryImpl(authService, errorMapper);

      expect(await repository.getCurrentUser(), const Right(testUserA));
      expect(
        (await repository.resendVerificationEmail('owner@shop.com')).isRight(),
        isTrue,
      );

      authService.errorToThrow = const sb.AuthException('rate limited');
      expect(
        await repository.resendVerificationEmail('owner@shop.com'),
        const Left<AppFailure, void>(AppFailure(AppErrorCode.auth)),
      );
    });
  });

  group('VerifyEmailCubit and VerifyEmailScreen', () {
    test(
      'resends verification email and checks verified session into coordinator',
      () async {
        final backend = FakeAuthBackend();
        final session = await createInitializedSessionCubit(backend);
        final cubit = VerifyEmailCubit(
          ResendVerificationEmailUseCase(backend),
          CheckEmailVerifiedUseCase(backend, backend),
          session,
        );
        addTearDown(() async {
          await cubit.close();
          await session.close();
          await backend.dispose();
        });

        await cubit.resendVerificationEmail(testUnverifiedUser.email);
        expect(backend.resendCalls, 1);
        expect(cubit.state.feedback, AuthFeedback.verificationResent);

        await cubit.checkEmailVerified();
        expect(cubit.state.feedback, AuthFeedback.emailNotVerifiedYet);

        backend.currentUser = testUserA;
        backend.linkedUserId = testUserA.id;
        await cubit.checkEmailVerified(email: testUserA.email);
        expect(session.state.status, AuthStatus.authenticated);
        expect(session.state.user, testUserA);
      },
    );

    testWidgets('resends link and checks verification status', (tester) async {
      final backend = FakeAuthBackend();
      final session = await createInitializedSessionCubit(backend);
      final cubit = VerifyEmailCubit(
        ResendVerificationEmailUseCase(backend),
        CheckEmailVerifiedUseCase(backend, backend),
        session,
      );
      addTearDown(() async {
        await cubit.close();
        await session.close();
        await backend.dispose();
      });

      await pumpAuthScreen(
        tester,
        const VerifyEmailScreen(email: 'shop@example.com'),
        providers: [
          BlocProvider<AuthSessionCubit>.value(value: session),
          BlocProvider<VerifyEmailCubit>.value(value: cubit),
        ],
      );
      final l10n = tester.element(find.byType(VerifyEmailScreen)).l10n;

      expect(find.text('shop@example.com'), findsOneWidget);
      expect(
        find.text(l10n.authVerifySubtitle('shop@example.com')),
        findsOneWidget,
      );

      await tapAuthButton(tester, l10n.authResendVerification);
      expect(backend.resendCalls, 1);
      expect(find.text(l10n.authResendSent), findsOneWidget);
      await tapAuthButton(tester, l10n.ok);

      await tapAuthButton(tester, l10n.authVerifiedAction);
      expect(find.text(l10n.authEmailNotVerifiedYet), findsOneWidget);
    });
  });
}
