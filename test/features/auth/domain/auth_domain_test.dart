import 'dart:async';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_outcome.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:daftariapp/features/auth/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const userA = AuthUser(
  id: 'user-a',
  email: 'owner@shop.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);
const userB = AuthUser(
  id: 'user-b',
  email: 'other@shop.com',
  shopName: 'Other Shop',
  emailVerified: true,
);
const unverifiedUser = AuthUser(
  id: 'user-c',
  email: 'new@shop.com',
  shopName: 'New Shop',
  emailVerified: false,
);

const validationFailure = AppFailure(AppErrorCode.validation);
const authFailure = AppFailure(AppErrorCode.auth);
const storageFailure = AppFailure(AppErrorCode.storage);
const databaseFailure = AppFailure(AppErrorCode.database);

class FakeAuthRepository implements AuthRepository {
  @override
  bool isConfigured = true;

  String? linkedUserId;
  bool localDataExists = true;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int linkCalls = 0;
  int resetCalls = 0;
  int updatePasswordCalls = 0;
  Object? lastArgs;

  Either<AppFailure, AuthUser?> currentUserResult = const Right(userA);
  Either<AppFailure, AuthUser> signInResult = const Right(userA);
  Either<AppFailure, AuthUser> signUpResult = const Right(unverifiedUser);
  Either<AppFailure, void> signOutResult = const Right(null);
  Either<AppFailure, void> resetResult = const Right(null);
  Either<AppFailure, void> updatePasswordResult = const Right(null);
  Either<AppFailure, LedgerLinkStatus>? linkStatusOverride;
  Future<Either<AppFailure, LedgerLinkStatus>> Function(String)?
  getLedgerLinkStatusHook;
  Either<AppFailure, LedgerLinkStatus>? linkResultOverride;
  Either<AppFailure, bool>? hasLocalDataOverride;
  Future<Either<AppFailure, bool>> Function()? hasLocalDataHook;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => const Stream.empty();

  @override
  Future<Either<AppFailure, AuthUser?>> getCurrentUser() async =>
      currentUserResult;

  @override
  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastArgs = (email, password);
    signInResult.match((_) {}, (user) => currentUserResult = Right(user));
    return signInResult;
  }

  @override
  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) async {
    signUpCalls++;
    lastArgs = (email, password, shopName);
    signUpResult.match((_) {}, (user) => currentUserResult = Right(user));
    return signUpResult;
  }

  @override
  Future<Either<AppFailure, void>> signOut({String? expectedUserId}) async {
    if (expectedUserId != null) {
      final activeUser = currentUserResult.getOrElse((_) => null);
      if (activeUser == null || activeUser.id != expectedUserId) {
        return const Right(null);
      }
    }
    signOutCalls++;
    return signOutResult;
  }

  @override
  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastArgs = email;
    return resetResult;
  }

  @override
  Future<Either<AppFailure, void>> resendVerificationEmail(String email) async {
    lastArgs = email;
    return const Right(null);
  }

  @override
  Future<Either<AppFailure, void>> updatePassword(String newPassword) async {
    updatePasswordCalls++;
    lastArgs = newPassword;
    return updatePasswordResult;
  }

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  ) async {
    if (getLedgerLinkStatusHook != null) {
      return getLedgerLinkStatusHook!(userId);
    }
    if (linkStatusOverride != null) return linkStatusOverride!;
    if (linkedUserId == null) return const Right(LedgerLinkStatus.unlinked);
    if (linkedUserId == userId) {
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    return const Right(LedgerLinkStatus.linkedToOtherUser);
  }

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> linkLedgerToUser(
    String userId,
  ) async {
    linkCalls++;
    if (linkResultOverride != null) return linkResultOverride!;
    if (linkedUserId == null) {
      linkedUserId = userId;
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    if (linkedUserId == userId) {
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    return const Right(LedgerLinkStatus.linkedToOtherUser);
  }

  @override
  Future<Either<AppFailure, bool>> hasLocalLedgerData() async {
    if (hasLocalDataHook != null) return hasLocalDataHook!();
    if (hasLocalDataOverride != null) return hasLocalDataOverride!;
    return Right(localDataExists);
  }
}

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  group('Entities equality', () {
    test('AuthUser compares all fields', () {
      expect(
        userA,
        const AuthUser(
          id: 'user-a',
          email: 'owner@shop.com',
          shopName: 'Al-Amana Grocery',
          emailVerified: true,
        ),
      );
      expect(
        userA,
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
      expect(const AuthSignedIn(user: userA), const AuthSignedIn(user: userA));
      expect(
        const AuthEmailVerificationRequired(email: 'a@b.com'),
        const AuthEmailVerificationRequired(email: 'a@b.com'),
      );
      expect(
        const AuthLinkConfirmationRequired(user: userA, hasLocalData: true),
        const AuthLinkConfirmationRequired(user: userA, hasLocalData: true),
      );
      expect(
        const AuthLinkConfirmationRequired(user: userA, hasLocalData: true),
        isNot(
          const AuthLinkConfirmationRequired(user: userA, hasLocalData: false),
        ),
      );
      expect(
        const AuthAccountMismatchBlocked(),
        const AuthAccountMismatchBlocked(),
      );
      expect(
        const AuthSessionSignedIn(userA),
        const AuthSessionSignedIn(userA),
      );
      expect(const AuthSessionSignedOut(), const AuthSessionSignedOut());
      expect(
        const AuthSessionPasswordRecovery(userA),
        const AuthSessionPasswordRecovery(userA),
      );
      expect(
        const AuthSessionFailure(authFailure),
        const AuthSessionFailure(authFailure),
      );
    });
  });

  group('SignInUseCase', () {
    for (final invalid in [
      ('', 'secret123'),
      ('bad-email', 'secret123'),
      ('owner@shop.com', 'short'),
      ('owner@shop.com', '        '),
    ]) {
      test('rejects invalid input $invalid without calling repo', () async {
        final result = await SignInUseCase(repository)(
          email: invalid.$1,
          password: invalid.$2,
        );
        expect(result, const Left<AppFailure, AuthOutcome>(validationFailure));
        expect(repository.signInCalls, 0);
      });
    }

    test('trims email, preserves untrimmed password, and returns signedIn when linked to current user', () async {
      repository.linkedUserId = userA.id;
      final result = await SignInUseCase(repository)(
        email: '  owner@shop.com  ',
        password: '  secret12  ',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthSignedIn(user: userA)),
      );
      expect(repository.lastArgs, ('owner@shop.com', '  secret12  '));
      expect(repository.signOutCalls, 0);
      expect(repository.linkCalls, 0);
    });

    test('requires deliberate confirmation on first link when unlinked (with and without local data)', () async {
      repository.localDataExists = true;
      final withData = await SignInUseCase(repository)(
        email: 'owner@shop.com',
        password: 'password1',
      );
      expect(
        withData,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: userA, hasLocalData: true),
        ),
      );
      expect(repository.linkedUserId, isNull);
      expect(repository.linkCalls, 0);

      repository.localDataExists = false;
      final withoutData = await SignInUseCase(repository)(
        email: 'owner@shop.com',
        password: 'password1',
      );
      expect(
        withoutData,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: userA, hasLocalData: false),
        ),
      );
      expect(repository.linkedUserId, isNull);
    });

    test('blocks mismatched account, signs out immediately, and preserves original linkedUserId', () async {
      repository.linkedUserId = userA.id;
      repository.signInResult = const Right(userB);

      final result = await SignInUseCase(repository)(
        email: 'other@shop.com',
        password: 'password1',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, userA.id);
      expect(repository.linkCalls, 0);
    });

    test('returns failure if mismatch signOut fails', () async {
      repository.linkedUserId = userA.id;
      repository.signInResult = const Right(userB);
      repository.signOutResult = const Left(authFailure);

      final result = await SignInUseCase(repository)(
        email: 'other@shop.com',
        password: 'password1',
      );

      expect(result, const Left<AppFailure, AuthOutcome>(authFailure));
      expect(repository.linkedUserId, userA.id);
    });

    test(
      'signs out and returns failure if link status or local data check fails',
      () async {
        repository.linkStatusOverride = const Left(storageFailure);
        final statusErr = await SignInUseCase(repository)(
          email: 'owner@shop.com',
          password: 'password1',
        );
        expect(statusErr, const Left<AppFailure, AuthOutcome>(storageFailure));
        expect(repository.signOutCalls, 1);

        repository.linkStatusOverride = null;
        repository.hasLocalDataOverride = const Left(databaseFailure);
        final dbErr = await SignInUseCase(repository)(
          email: 'owner@shop.com',
          password: 'password1',
        );
        expect(dbErr, const Left<AppFailure, AuthOutcome>(databaseFailure));
        expect(repository.signOutCalls, 2);
      },
    );

    test(
      'returns emailVerificationRequired when user email is not verified',
      () async {
        repository.signInResult = const Right(unverifiedUser);
        final result = await SignInUseCase(repository)(
          email: 'new@shop.com',
          password: 'password1',
        );

        expect(
          result,
          const Right<AppFailure, AuthOutcome>(
            AuthEmailVerificationRequired(email: 'new@shop.com'),
          ),
        );
        expect(repository.linkCalls, 0);
      },
    );

    test('forwards repository auth failure', () async {
      repository.signInResult = const Left(authFailure);
      final result = await SignInUseCase(repository)(
        email: 'owner@shop.com',
        password: 'password1',
      );

      expect(result, const Left<AppFailure, AuthOutcome>(authFailure));
    });

    test('scoped evaluation cleanup preserves replacement account on mismatch and lookup failures', () async {
      // 1) Mismatch while session switches from A to B
      repository.linkedUserId = userB.id;
      repository.signInResult = const Right(userA);
      final statusStarted = Completer<void>();
      final releaseStatus = Completer<Either<AppFailure, LedgerLinkStatus>>();
      repository.getLedgerLinkStatusHook = (_) {
        if (!statusStarted.isCompleted) statusStarted.complete();
        return releaseStatus.future;
      };

      final mismatchSignIn = SignInUseCase(repository)(
        email: userA.email,
        password: 'password1',
      );
      await statusStarted.future;
      repository.currentUserResult = const Right(userB);
      releaseStatus.complete(const Right(LedgerLinkStatus.linkedToOtherUser));

      expect(
        await mismatchSignIn,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(repository.signOutCalls, 0);
      expect(repository.currentUserResult, const Right(userB));
      expect(repository.linkedUserId, userB.id);

      // 2) Owner-read failure while session switches from A to B
      final failureStarted = Completer<void>();
      final releaseFailure = Completer<Either<AppFailure, LedgerLinkStatus>>();
      repository.getLedgerLinkStatusHook = (_) {
        if (!failureStarted.isCompleted) failureStarted.complete();
        return releaseFailure.future;
      };

      final statusFailureSignIn = SignInUseCase(repository)(
        email: userA.email,
        password: 'password1',
      );
      await failureStarted.future;
      repository.currentUserResult = const Right(userB);
      releaseFailure.complete(const Left(storageFailure));

      expect(
        await statusFailureSignIn,
        const Left<AppFailure, AuthOutcome>(storageFailure),
      );
      expect(repository.signOutCalls, 0);
      expect(repository.currentUserResult, const Right(userB));
      expect(repository.linkedUserId, userB.id);

      // 3) Local-data-read failure while session switches from A to B
      repository.getLedgerLinkStatusHook = null;
      repository.linkedUserId = null;
      final localDataStarted = Completer<void>();
      final releaseLocalData = Completer<Either<AppFailure, bool>>();
      repository.hasLocalDataHook = () {
        if (!localDataStarted.isCompleted) localDataStarted.complete();
        return releaseLocalData.future;
      };

      final localDataFailureSignIn = SignInUseCase(repository)(
        email: userA.email,
        password: 'password1',
      );
      await localDataStarted.future;
      repository.currentUserResult = const Right(userB);
      releaseLocalData.complete(const Left(databaseFailure));

      expect(
        await localDataFailureSignIn,
        const Left<AppFailure, AuthOutcome>(databaseFailure),
      );
      expect(repository.signOutCalls, 0);
      expect(repository.currentUserResult, const Right(userB));
    });
  });

  group('SignUpUseCase', () {
    for (final invalid in [
      ('owner@shop.com', 'password1', ''),
      ('owner@shop.com', 'password1', '   '),
      ('invalid-email', 'password1', 'Shop'),
      ('owner@shop.com', '1234567', 'Shop'),
    ]) {
      test('rejects invalid input $invalid without calling repo', () async {
        final result = await SignUpUseCase(repository)(
          email: invalid.$1,
          password: invalid.$2,
          shopName: invalid.$3,
        );
        expect(result, const Left<AppFailure, AuthOutcome>(validationFailure));
        expect(repository.signUpCalls, 0);
      });
    }

    test('trims email and shopName, preserves password, and returns emailVerificationRequired', () async {
      final result = await SignUpUseCase(repository)(
        email: '  new@shop.com ',
        password: ' password1 ',
        shopName: '  Al-Amana Grocery  ',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(
          AuthEmailVerificationRequired(email: 'new@shop.com'),
        ),
      );
      expect(repository.lastArgs, (
        'new@shop.com',
        ' password1 ',
        'Al-Amana Grocery',
      ));
      expect(repository.linkCalls, 0);
    });

    test('enforces link confirmation when signUp returns verified user on unlinked ledger', () async {
      repository.signUpResult = const Right(userA);
      final result = await SignUpUseCase(repository)(
        email: 'owner@shop.com',
        password: 'password1',
        shopName: 'Al-Amana Grocery',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(
          AuthLinkConfirmationRequired(user: userA, hasLocalData: true),
        ),
      );
      expect(repository.linkedUserId, isNull);
    });

    test('blocks mismatched account when signUp returns verified user for another owner', () async {
      repository.linkedUserId = userA.id;
      repository.signUpResult = const Right(userB);
      final result = await SignUpUseCase(repository)(
        email: 'other@shop.com',
        password: 'password1',
        shopName: 'Other Shop',
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome>(AuthAccountMismatchBlocked()),
      );
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, userA.id);
    });
  });

  group('ConfirmLedgerLinkUseCase', () {
    test('canceling signs out immediately without linking ledger', () async {
      repository.currentUserResult = const Right(userA);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: false,
      );

      expect(result, const Right<AppFailure, AuthOutcome?>(null));
      expect(repository.signOutCalls, 1);
      expect(repository.linkCalls, 0);
      expect(repository.linkedUserId, isNull);
    });

    test('stale cancellation after session switch leaves replacement account signed in', () async {
      repository.currentUserResult = const Right(userB);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: false,
      );

      expect(result, const Right<AppFailure, AuthOutcome?>(null));
      expect(repository.signOutCalls, 0);
      expect(repository.linkCalls, 0);
      expect(repository.linkedUserId, isNull);
      expect(repository.currentUserResult, const Right(userB));
    });

    test('confirming on unlinked ledger persists linkedUserId and returns signedIn', () async {
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthSignedIn(user: userA)),
      );
      expect(repository.linkCalls, 1);
      expect(repository.linkedUserId, userA.id);
      expect(repository.signOutCalls, 0);
    });

    test('confirming when already linked to current user returns signedIn without changing owner', () async {
      repository.linkedUserId = userA.id;
      repository.currentUserResult = const Right(userA);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthSignedIn(user: userA)),
      );
      expect(repository.linkedUserId, userA.id);
    });

    test('confirming when linked to another user blocks, signs out, and preserves original owner', () async {
      repository.linkedUserId = userA.id;
      repository.currentUserResult = const Right(userB);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userB,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(AuthAccountMismatchBlocked()),
      );
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, userA.id);
    });

    test('forwards link storage failure', () async {
      repository.linkResultOverride = const Left(storageFailure);
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: true,
      );

      expect(result, const Left<AppFailure, AuthOutcome?>(storageFailure));
      expect(repository.linkedUserId, isNull);
    });

    test('refuses to link unverified user', () async {
      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: unverifiedUser,
        confirmed: true,
      );

      expect(
        result,
        const Right<AppFailure, AuthOutcome?>(
          AuthEmailVerificationRequired(email: 'new@shop.com'),
        ),
      );
      expect(repository.linkCalls, 0);
      expect(repository.linkedUserId, isNull);
    });

    test(
      'rejects stale confirmation after sign-out without writing owner',
      () async {
        repository.currentUserResult = const Right(null);
        final result = await ConfirmLedgerLinkUseCase(repository)(
          user: userA,
          confirmed: true,
        );

        expect(result, const Left<AppFailure, AuthOutcome?>(authFailure));
        expect(repository.linkCalls, 0);
        expect(repository.linkedUserId, isNull);
      },
    );

    test(
      'rejects stale confirmation after session change without writing owner',
      () async {
        repository.currentUserResult = const Right(userB);
        final result = await ConfirmLedgerLinkUseCase(repository)(
          user: userA,
          confirmed: true,
        );

        expect(result, const Left<AppFailure, AuthOutcome?>(authFailure));
        expect(repository.linkCalls, 0);
        expect(repository.linkedUserId, isNull);
      },
    );
  });

  group('SignOutUseCase', () {
    test('signs out while preserving linkedUserId and local ledger', () async {
      repository.linkedUserId = userA.id;
      repository.localDataExists = true;

      final result = await SignOutUseCase(repository)();

      expect(result.isRight(), isTrue);
      expect(repository.signOutCalls, 1);
      expect(repository.linkedUserId, userA.id);
      expect(repository.localDataExists, isTrue);
    });

    test('forwards signOut failure', () async {
      repository.signOutResult = const Left(authFailure);
      final result = await SignOutUseCase(repository)();
      expect(result, const Left<AppFailure, void>(authFailure));
    });
  });

  group('SendPasswordResetUseCase', () {
    test('rejects invalid email without calling repository', () async {
      final result = await SendPasswordResetUseCase(repository)('not-an-email');
      expect(result, const Left<AppFailure, void>(validationFailure));
      expect(repository.resetCalls, 0);
    });

    test('trims email and forwards success or failure', () async {
      final ok = await SendPasswordResetUseCase(repository)(
        '  owner@shop.com ',
      );
      expect(ok.isRight(), isTrue);
      expect(repository.lastArgs, 'owner@shop.com');
      expect(repository.resetCalls, 1);

      repository.resetResult = const Left(authFailure);
      final err = await SendPasswordResetUseCase(repository)('owner@shop.com');
      expect(err, const Left<AppFailure, void>(authFailure));
    });
  });

  group('UpdatePasswordUseCase', () {
    test(
      'rejects short or whitespace-only password without calling repository',
      () async {
        expect(
          await UpdatePasswordUseCase(repository)('1234567'),
          const Left<AppFailure, void>(validationFailure),
        );
        expect(
          await UpdatePasswordUseCase(repository)('        '),
          const Left<AppFailure, void>(validationFailure),
        );
        expect(repository.updatePasswordCalls, 0);
      },
    );

    test(
      'preserves untrimmed password and forwards success or failure',
      () async {
        final ok = await UpdatePasswordUseCase(repository)('  newpass1  ');
        expect(ok.isRight(), isTrue);
        expect(repository.lastArgs, '  newpass1  ');
        expect(repository.updatePasswordCalls, 1);

        repository.updatePasswordResult = const Left(authFailure);
        final err = await UpdatePasswordUseCase(repository)('newpass1');
        expect(err, const Left<AppFailure, void>(authFailure));
      },
    );
  });
}
