import 'dart:async';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/auth/update_password/data/repositories/update_password_repository_impl.dart';
import 'package:daftariapp/features/auth/update_password/domain/usecases/update_password_usecase.dart';
import 'package:daftariapp/features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import 'package:daftariapp/features/auth/update_password/presentation/screens/update_password_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../auth_test_fakes.dart';

void main() {
  group('UpdatePasswordRepositoryImpl', () {
    test('maps TimeoutException to network AppFailure', () async {
      final authService = FakeAuthService()
        ..errorToThrow = TimeoutException('timeout');
      final errorMapper = AuthErrorMapper(
        ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
      );
      final repository = UpdatePasswordRepositoryImpl(authService, errorMapper);

      expect(
        await repository.updatePassword('newpass1'),
        const Left<AppFailure, void>(AppFailure(AppErrorCode.network)),
      );
    });
  });

  group('UpdatePasswordUseCase', () {
    late FakeAuthBackend backend;

    setUp(() => backend = FakeAuthBackend());
    tearDown(() => backend.dispose());

    test(
      'rejects short or whitespace-only password without calling repository',
      () async {
        expect(
          await UpdatePasswordUseCase(backend)('1234567'),
          const Left<AppFailure, void>(testValidationFailure),
        );
        expect(
          await UpdatePasswordUseCase(backend)('        '),
          const Left<AppFailure, void>(testValidationFailure),
        );
        expect(backend.updatePasswordCalls, 0);
      },
    );

    test(
      'preserves untrimmed password and forwards success or failure',
      () async {
        final ok = await UpdatePasswordUseCase(backend)('  newpass1  ');
        expect(ok.isRight(), isTrue);
        expect(backend.lastArgs, '  newpass1  ');
        expect(backend.updatePasswordCalls, 1);

        backend.updatePasswordResult = const Left(testAuthFailure);
        final err = await UpdatePasswordUseCase(backend)('newpass1');
        expect(err, const Left<AppFailure, void>(testAuthFailure));
      },
    );
  });

  group('UpdatePasswordCubit and UpdatePasswordScreen', () {
    test('completes recovery via session coordinator on success', () async {
      final backend = FakeAuthBackend(linkedUserId: testUserA.id);
      final session = await createInitializedSessionCubit(backend);
      final cubit = UpdatePasswordCubit(
        UpdatePasswordUseCase(backend),
        session,
      );
      addTearDown(() async {
        await cubit.close();
        await session.close();
        await backend.dispose();
      });

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionPasswordRecovery(testUserA));
      await Future<void>.delayed(Duration.zero);
      expect(session.state.passwordRecoveryPending, isTrue);

      final updated = await cubit.updatePassword('newpassword1');
      expect(updated, isTrue);
      expect(session.state.passwordRecoveryPending, isFalse);
      expect(session.state.status, AuthStatus.authenticated);
      expect(session.state.feedback, AuthFeedback.passwordUpdated);
    });

    testWidgets('validates confirmation and updates password', (tester) async {
      final backend = FakeAuthBackend(
        currentUser: testUserA,
        linkedUserId: testUserA.id,
      );
      final session = await createInitializedSessionCubit(backend);
      final cubit = UpdatePasswordCubit(
        UpdatePasswordUseCase(backend),
        session,
      );
      addTearDown(() async {
        await cubit.close();
        await session.close();
        await backend.dispose();
      });

      await pumpAuthScreen(
        tester,
        const UpdatePasswordScreen(),
        providers: [
          BlocProvider<AuthSessionCubit>.value(value: session),
          BlocProvider<UpdatePasswordCubit>.value(value: cubit),
        ],
      );
      final l10n = tester.element(find.byType(UpdatePasswordScreen)).l10n;

      await tester.enterText(
        authFormField('auth-update-password'),
        'password1',
      );
      await tester.enterText(authFormField('auth-update-confirm'), 'password2');
      await tapAuthButton(tester, l10n.authUpdatePasswordAction);
      expect(find.text(l10n.authPasswordMismatch), findsOneWidget);

      await tester.enterText(authFormField('auth-update-confirm'), 'password1');
      await tapAuthButton(tester, l10n.authUpdatePasswordAction);
      expect(find.text(l10n.authPasswordUpdated), findsOneWidget);
    });
  });
}
