import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/auth/login/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/login/presentation/cubit/login_cubit.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../auth_test_fakes.dart';

void main() {
  group('AuthSessionCubit startup initialization', () {
    blocTest<AuthSessionCubit, AuthSessionState>(
      'degrades safely when unconfigured',
      build: () => buildSessionCubit(FakeAuthBackend(isConfigured: false)),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthSessionState(
          initialized: true,
          isConfigured: false,
          status: AuthStatus.unauthenticated,
        ),
      ],
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'restores authenticated session when owner matches',
      build: () => buildSessionCubit(
        FakeAuthBackend(currentUser: testUserA, linkedUserId: testUserA.id),
      ),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthSessionState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.authenticated,
          user: testUserA,
        ),
      ],
    );

    test('blocks mismatched restored session on cold restart and preserves original owner', () async {
      final backend = FakeAuthBackend(
        currentUser: testUserB,
        linkedUserId: testUserA.id,
      );
      final cubit = buildSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      await cubit.initialize();

      expect(cubit.state.initialized, isTrue);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
      expect(cubit.state.feedback, AuthFeedback.accountMismatchBlocked);
      expect(backend.signOutCalls, 1);
      expect(backend.linkedUserId, testUserA.id);
    });

    blocTest<AuthSessionCubit, AuthSessionState>(
      'requests confirmation when restored session is on unlinked ledger',
      build: () => buildSessionCubit(
        FakeAuthBackend(currentUser: testUserA, hasLocalData: true),
      ),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthSessionState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.linkConfirmationRequired,
          user: testUserA,
          pendingHasLocalData: true,
        ),
      ],
    );
  });

  group('AuthSessionCubit linking, sign out, stream, and recovery', () {
    test(
      'confirmLedgerLink cancels, links, and signOut preserves owner',
      () async {
        final backend = FakeAuthBackend();
        final session = await createInitializedSessionCubit(backend);
        final loginCubit = LoginCubit(SignInUseCase(backend, backend), session);
        addTearDown(() async {
          await loginCubit.close();
          await session.close();
          await backend.dispose();
        });

        await loginCubit.signIn(email: testUserA.email, password: 'password1');
        expect(session.state.status, AuthStatus.linkConfirmationRequired);
        expect(session.state.user, testUserA);
        expect(backend.linkedUserId, isNull);

        await session.confirmLedgerLink(confirmed: false);
        expect(session.state.status, AuthStatus.unauthenticated);
        expect(backend.linkedUserId, isNull);
        expect(backend.signOutCalls, 1);

        await loginCubit.signIn(email: testUserA.email, password: 'password1');
        expect(session.state.status, AuthStatus.linkConfirmationRequired);

        await session.confirmLedgerLink(confirmed: true);
        expect(session.state.status, AuthStatus.authenticated);
        expect(session.state.user, testUserA);
        expect(session.state.feedback, AuthFeedback.ledgerLinked);
        expect(backend.linkedUserId, testUserA.id);

        await session.signOut();
        expect(session.state.status, AuthStatus.unauthenticated);
        expect(session.state.feedback, AuthFeedback.signedOut);
        expect(backend.linkedUserId, testUserA.id);
      },
    );

    test('confirmLedgerLink ignores stale expectedUserId when another account replaced it', () async {
      final backend = FakeAuthBackend();
      final cubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionSignedIn(testUserA));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.linkConfirmationRequired);
      expect(cubit.state.user, testUserA);

      backend.currentUser = testUserB;
      backend.events.add(const AuthSessionSignedIn(testUserB));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.linkConfirmationRequired);
      expect(cubit.state.user, testUserB);

      await cubit.confirmLedgerLink(
        confirmed: true,
        expectedUserId: testUserA.id,
      );
      expect(backend.linkLedgerCalls, 0);
      expect(backend.linkedUserId, isNull);
      expect(backend.signOutCalls, 0);
      expect(cubit.state.status, AuthStatus.linkConfirmationRequired);
      expect(cubit.state.user, testUserB);

      await cubit.confirmLedgerLink(
        confirmed: false,
        expectedUserId: testUserA.id,
      );
      expect(backend.linkLedgerCalls, 0);
      expect(backend.signOutCalls, 0);
      expect(backend.currentUser, testUserB);
      expect(cubit.state.status, AuthStatus.linkConfirmationRequired);
      expect(cubit.state.user, testUserB);
    });

    test('newer signed-out event invalidates pending owner lookup from older session', () async {
      final pendingLookup = Completer<Either<AppFailure, LedgerLinkStatus>>();
      final backend = FakeAuthBackend(linkedUserId: testUserA.id)
        ..onGetLedgerLinkStatus = (_) => pendingLookup.future;
      final cubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionSignedIn(testUserA));
      await Future<void>.delayed(Duration.zero);

      backend.currentUser = null;
      backend.events.add(const AuthSessionSignedOut());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);

      pendingLookup.complete(const Right(LedgerLinkStatus.linkedToCurrentUser));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
    });

    test('newer signed-in event invalidates pending owner lookup from older session', () async {
      final pendingLookupA = Completer<Either<AppFailure, LedgerLinkStatus>>();
      final backend = FakeAuthBackend(linkedUserId: testUserB.id)
        ..onGetLedgerLinkStatus = (userId) async {
          if (userId == testUserA.id) return pendingLookupA.future;
          return const Right(LedgerLinkStatus.linkedToCurrentUser);
        };
      final cubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionSignedIn(testUserA));
      await Future<void>.delayed(Duration.zero);

      backend.currentUser = testUserB;
      backend.events.add(const AuthSessionSignedIn(testUserB));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.user, testUserB);

      pendingLookupA.complete(const Right(LedgerLinkStatus.linkedToOtherUser));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.user, testUserB);
      expect(cubit.state.feedback, AuthFeedback.none);
      expect(backend.signOutCalls, 0);
    });

    test('handles stream failures and passwordRecovery routing flag', () async {
      final backend = FakeAuthBackend(linkedUserId: testUserA.id);
      final cubit = buildSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      var routeNotifications = 0;
      cubit.addListener(() => routeNotifications++);
      await cubit.initialize();

      backend.events.add(
        const AuthSessionFailure(AppFailure(AppErrorCode.network)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.feedback, AuthFeedback.networkError);

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionPasswordRecovery(testUserA));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.passwordRecovery);
      expect(cubit.state.passwordRecoveryPending, isTrue);
      expect(routeNotifications, 1);

      final token = cubit.beginAuthAction(userId: testUserA.id);
      final completed = await cubit.completePasswordRecovery(token);
      cubit.endAuthAction(token);
      expect(completed, isTrue);
      expect(cubit.state.passwordRecoveryPending, isFalse);
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.feedback, AuthFeedback.passwordUpdated);
      expect(routeNotifications, 2);
    });

    test('password recovery rejects mismatched account, signs it out, and preserves ledger owner', () async {
      final backend = FakeAuthBackend(
        currentUser: testUserB,
        linkedUserId: testUserA.id,
      );
      final cubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      backend.currentUser = testUserB;
      backend.events.add(const AuthSessionPasswordRecovery(testUserB));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.passwordRecoveryPending, isFalse);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
      expect(cubit.state.feedback, AuthFeedback.accountMismatchBlocked);
      expect(backend.currentUser, isNull);
      expect(backend.linkedUserId, testUserA.id);
    });

    test('cancelling password recovery signs out provider session and stays signed out on restart', () async {
      final backend = FakeAuthBackend(linkedUserId: testUserA.id);
      final cubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await cubit.close();
        await backend.dispose();
      });

      backend.currentUser = testUserA;
      backend.events.add(const AuthSessionPasswordRecovery(testUserA));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.passwordRecoveryPending, isTrue);

      final cancelled = await cubit.cancelPasswordRecovery();
      expect(cancelled, isTrue);
      expect(cubit.state.passwordRecoveryPending, isFalse);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
      expect(backend.currentUser, isNull);
      expect(backend.linkedUserId, testUserA.id);

      final restarted = await createInitializedSessionCubit(backend);
      addTearDown(restarted.close);
      expect(restarted.state.status, AuthStatus.unauthenticated);
      expect(restarted.state.user, isNull);
      expect(backend.currentUser, isNull);
    });

    test('P11-14 startup and passive mismatch preserve isolation feedback when signOut emits signed-out event', () async {
      final startupBackend = FakeAuthBackend(
        currentUser: testUserB,
        linkedUserId: testUserA.id,
      )..emitSignedOutEvent = true;
      final startupCubit = await createInitializedSessionCubit(startupBackend);
      addTearDown(() async {
        await startupCubit.close();
        await startupBackend.dispose();
      });

      expect(startupCubit.state.initialized, isTrue);
      expect(startupCubit.state.status, AuthStatus.unauthenticated);
      expect(startupCubit.state.user, isNull);
      expect(startupCubit.state.feedback, AuthFeedback.accountMismatchBlocked);
      expect(startupBackend.linkedUserId, testUserA.id);
      expect(startupBackend.currentUser, isNull);

      final passiveBackend = FakeAuthBackend(linkedUserId: testUserA.id)
        ..emitSignedOutEvent = true;
      final passiveCubit = await createInitializedSessionCubit(passiveBackend);
      addTearDown(() async {
        await passiveCubit.close();
        await passiveBackend.dispose();
      });

      passiveBackend.currentUser = testUserB;
      passiveBackend.events.add(const AuthSessionSignedIn(testUserB));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(passiveCubit.state.status, AuthStatus.unauthenticated);
      expect(passiveCubit.state.user, isNull);
      expect(passiveCubit.state.feedback, AuthFeedback.accountMismatchBlocked);
      expect(passiveBackend.linkedUserId, testUserA.id);
      expect(passiveBackend.currentUser, isNull);
    });
  });
}
