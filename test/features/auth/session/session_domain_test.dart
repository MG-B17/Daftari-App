import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_outcome.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/sign_out_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../auth_test_fakes.dart';

void main() {
  late FakeAuthBackend repository;

  setUp(() => repository = FakeAuthBackend(currentUser: testUserA));
  tearDown(() => repository.dispose());

  group('Entities equality', () {
    test('AuthUser compares all fields', () {
      expect(
        testUserA,
        const AuthUser(
          id: 'user-a',
          email: 'owner@shop.com',
          shopName: 'Al-Amana Grocery',
          emailVerified: true,
        ),
      );
      expect(
        testUserA,
        isNot(
          const AuthUser(
            id: 'user-a',
            email: 'owner@shop.com',
            shopName: 'Al-Amana Grocery',
            emailVerified: false,
          ),
        ),
      );
    });

    test('AuthOutcome and AuthSessionEvent value equality', () {
      expect(
        const AuthSignedIn(user: testUserA),
        const AuthSignedIn(user: testUserA),
      );
      expect(
        const AuthEmailVerificationRequired(email: 'a@b.com'),
        const AuthEmailVerificationRequired(email: 'a@b.com'),
      );
      expect(
        const AuthLinkConfirmationRequired(user: testUserA, hasLocalData: true),
        const AuthLinkConfirmationRequired(user: testUserA, hasLocalData: true),
      );
      expect(
        const AuthLinkConfirmationRequired(user: testUserA, hasLocalData: true),
        isNot(
          const AuthLinkConfirmationRequired(
            user: testUserA,
            hasLocalData: false,
          ),
        ),
      );
      expect(
        const AuthAccountMismatchBlocked(),
        const AuthAccountMismatchBlocked(),
      );
      expect(
        const AuthSessionSignedIn(testUserA),
        const AuthSessionSignedIn(testUserA),
      );
      expect(const AuthSessionSignedOut(), const AuthSessionSignedOut());
      expect(
        const AuthSessionPasswordRecovery(testUserA),
        const AuthSessionPasswordRecovery(testUserA),
      );
      expect(
        const AuthSessionFailure(testAuthFailure),
        const AuthSessionFailure(testAuthFailure),
      );
    });
  });

  group('ConfirmLedgerLinkUseCase', () {
    test('canceling signs out immediately without linking ledger', () async {
      repository.currentUser = testUserA;
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserA,
        confirmed: false,
      );

      expect(result, const Right<AppFailure, AuthOutcome?>(null));
      expect(repository.signOutCalls, 1);
      expect(repository.linkLedgerCalls, 0);
      expect(repository.linkedUserId, isNull);
    });

    test('stale cancellation after session switch leaves replacement account signed in', () async {
      repository.currentUser = testUserB;
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserA,
        confirmed: false,
      );

      expect(result, const Right<AppFailure, AuthOutcome?>(null));
      expect(repository.signOutCalls, 0);
      expect(repository.linkLedgerCalls, 0);
      expect(repository.linkedUserId, isNull);
      expect(repository.currentUser, testUserB);
    });

    test('confirming on unlinked ledger persists linkedUserId and returns signedIn', () async {
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserA,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthSignedIn(user: testUserA)),
      );
      expect(repository.linkLedgerCalls, 1);
      expect(repository.linkedUserId, testUserA.id);
      expect(repository.signOutCalls, 0);
    });

    test('confirming when already linked to current user returns signedIn without changing owner', () async {
      repository.linkedUserId = testUserA.id;
      repository.currentUser = testUserA;
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserA,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthSignedIn(user: testUserA)),
      );
      expect(repository.linkedUserId, testUserA.id);
    });

    test('confirming when linked to another user blocks, signs out, and preserves original owner', () async {
      repository.linkedUserId = testUserA.id;
      repository.currentUser = testUserB;
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserB,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthAccountMismatchBlocked()),
      );
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, testUserA.id);
    });

    test('forwards link storage failure', () async {
      repository.linkResultOverride = const Left(testStorageFailure);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUserA,
        confirmed: true,
      );

      expect(result, const Left<AppFailure, AuthOutcome?>(testStorageFailure));
      expect(repository.linkedUserId, isNull);
    });

    test('refuses to link unverified user', () async {
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: testUnverifiedUser,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(
          AuthEmailVerificationRequired(email: 'pending@shop.com'),
        ),
      );
      expect(repository.linkLedgerCalls, 0);
      expect(repository.linkedUserId, isNull);
    });

    test(
      'rejects stale confirmation after sign-out without writing owner',
      () async {
        repository.currentUser = null;
        final result = await ConfirmLedgerLinkUseCase(repository)(
          user: testUserA,
          confirmed: true,
        );

        expect(result, const Left<AppFailure, AuthOutcome?>(testAuthFailure));
        expect(repository.linkLedgerCalls, 0);
        expect(repository.linkedUserId, isNull);
      },
    );

    test(
      'rejects stale confirmation after session change without writing owner',
      () async {
        repository.currentUser = testUserB;
        final result = await ConfirmLedgerLinkUseCase(repository)(
          user: testUserA,
          confirmed: true,
        );

        expect(result, const Left<AppFailure, AuthOutcome?>(testAuthFailure));
        expect(repository.linkLedgerCalls, 0);
        expect(repository.linkedUserId, isNull);
      },
    );
  });

  group('SignOutUseCase', () {
    test('signs out while preserving linkedUserId and local ledger', () async {
      repository.linkedUserId = testUserA.id;
      repository.hasLocalData = true;

      final result = await SignOutUseCase(repository)();

      expect(result.isRight(), isTrue);
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, testUserA.id);
      expect(repository.hasLocalData, isTrue);
    });

    test('forwards signOut failure', () async {
      repository.signOutResult = const Left(testAuthFailure);
      final result = await SignOutUseCase(repository)();
      expect(result, const Left<AppFailure, void>(testAuthFailure));
    });
  });
}
