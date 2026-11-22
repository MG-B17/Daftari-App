import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
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
import 'package:daftariapp/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:daftariapp/features/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _userA = AuthUser(
  id: 'user-a',
  email: 'owner@shop.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);
const _userB = AuthUser(
  id: 'user-b',
  email: 'other@shop.com',
  shopName: 'Other Shop',
  emailVerified: true,
);
const _unverified = AuthUser(
  id: 'user-c',
  email: 'pending@shop.com',
  shopName: 'Pending Shop',
  emailVerified: false,
);

class FakeCubitAuthRepository implements AuthRepository {
  FakeCubitAuthRepository({
    this.isConfigured = true,
    this.currentUser,
    this.linkedUserId,
    this.hasLocalData = true,
  });

  @override
  bool isConfigured;

  AuthUser? currentUser;
  String? linkedUserId;
  bool hasLocalData;

  final StreamController<AuthSessionEvent> events =
      StreamController<AuthSessionEvent>.broadcast();

  Either<AppFailure, AuthUser>? signInOverride;
  Either<AppFailure, AuthUser>? signUpOverride;
  Either<AppFailure, void> resetResult = const Right(null);
  Either<AppFailure, void> resendResult = const Right(null);
  Either<AppFailure, void> updatePasswordResult = const Right(null);

  int signOutCalls = 0;
  int resendCalls = 0;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => events.stream;

  @override
  Future<Either<AppFailure, AuthUser?>> getCurrentUser() async =>
      Right(currentUser);

  @override
  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = signInOverride ?? const Right(_userA);
    result.match((_) {}, (user) {
      if (user.emailVerified) currentUser = user;
    });
    return result;
  }

  @override
  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) async {
    final result = signUpOverride ?? const Right(_unverified);
    result.match((_) {}, (user) {
      if (user.emailVerified) currentUser = user;
    });
    return result;
  }

  @override
  Future<Either<AppFailure, void>> signOut({String? expectedUserId}) async {
    if (expectedUserId != null && currentUser?.id != expectedUserId) {
      return const Right(null);
    }
    signOutCalls++;
    currentUser = null;
    return const Right(null);
  }

  @override
  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email) async =>
      resetResult;

  @override
  Future<Either<AppFailure, void>> resendVerificationEmail(String email) async {
    resendCalls++;
    return resendResult;
  }

  @override
  Future<Either<AppFailure, void>> updatePassword(String newPassword) async =>
      updatePasswordResult;

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  ) async {
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
  Future<Either<AppFailure, bool>> hasLocalLedgerData() async =>
      Right(hasLocalData);

  Future<void> dispose() => events.close();
}

AuthCubit _buildCubit(FakeCubitAuthRepository repo) => AuthCubit(
  repo,
  SignInUseCase(repo),
  SignUpUseCase(repo),
  SignOutUseCase(repo),
  ConfirmLedgerLinkUseCase(repo),
  SendPasswordResetUseCase(repo),
  UpdatePasswordUseCase(repo),
);

void main() {
  group('AuthCubit startup initialization', () {
    blocTest<AuthCubit, AuthState>(
      'degrades safely when unconfigured',
      build: () => _buildCubit(FakeCubitAuthRepository(isConfigured: false)),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthState(
          initialized: true,
          isConfigured: false,
          status: AuthStatus.unauthenticated,
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'restores authenticated session when owner matches',
      build: () => _buildCubit(
        FakeCubitAuthRepository(currentUser: _userA, linkedUserId: _userA.id),
      ),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.authenticated,
          user: _userA,
        ),
      ],
    );

    test('blocks mismatched restored session on cold restart and preserves original owner', () async {
      final repo = FakeCubitAuthRepository(
        currentUser: _userB,
        linkedUserId: _userA.id,
      );
      final cubit = _buildCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.dispose();
      });

      await cubit.initialize();

      expect(cubit.state.initialized, isTrue);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
      expect(cubit.state.feedback, AuthFeedback.accountMismatchBlocked);
      expect(repo.signOutCalls, 1);
      expect(repo.linkedUserId, _userA.id);
    });

    blocTest<AuthCubit, AuthState>(
      'requests confirmation when restored session is on unlinked ledger',
      build: () => _buildCubit(
        FakeCubitAuthRepository(currentUser: _userA, hasLocalData: true),
      ),
      act: (cubit) => cubit.initialize(),
      expect: () => const [
        AuthState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.linkConfirmationRequired,
          user: _userA,
          pendingHasLocalData: true,
        ),
      ],
    );
  });

  group('AuthCubit sign in, linking, and sign out', () {
    test(
      'requires confirmation on first sign-in and links only when confirmed',
      () async {
        final repo = FakeCubitAuthRepository();
        final cubit = _buildCubit(repo);
        addTearDown(() async {
          await cubit.close();
          await repo.dispose();
        });
        await cubit.initialize();

        await cubit.signIn(email: _userA.email, password: 'password1');
        expect(cubit.state.status, AuthStatus.linkConfirmationRequired);
        expect(cubit.state.user, _userA);
        expect(repo.linkedUserId, isNull);

        await cubit.confirmLedgerLink(confirmed: false);
        expect(cubit.state.status, AuthStatus.unauthenticated);
        expect(repo.linkedUserId, isNull);
        expect(repo.signOutCalls, 1);

        await cubit.signIn(email: _userA.email, password: 'password1');
        expect(cubit.state.status, AuthStatus.linkConfirmationRequired);

        await cubit.confirmLedgerLink(confirmed: true);
        expect(cubit.state.status, AuthStatus.authenticated);
        expect(cubit.state.user, _userA);
        expect(cubit.state.feedback, AuthFeedback.ledgerLinked);
        expect(repo.linkedUserId, _userA.id);

        await cubit.signOut();
        expect(cubit.state.status, AuthStatus.unauthenticated);
        expect(cubit.state.feedback, AuthFeedback.signedOut);
        expect(repo.linkedUserId, _userA.id);
      },
    );

    test('emits unconfigured feedback when signing in unconfigured', () async {
      final repo = FakeCubitAuthRepository(isConfigured: false);
      final cubit = _buildCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.dispose();
      });
      await cubit.initialize();

      await cubit.signIn(email: _userA.email, password: 'password1');
      expect(cubit.state.feedback, AuthFeedback.unconfigured);
      expect(cubit.state.status, AuthStatus.unauthenticated);
    });

    test('sign up transitions to emailVerificationRequired', () async {
      final repo = FakeCubitAuthRepository();
      final cubit = _buildCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.dispose();
      });
      await cubit.initialize();

      await cubit.signUp(
        email: _unverified.email,
        password: 'password1',
        shopName: 'Pending Shop',
      );

      expect(cubit.state.status, AuthStatus.emailVerificationRequired);
      expect(cubit.state.pendingEmail, _unverified.email);

      await cubit.resendVerificationEmail(_unverified.email);
      expect(repo.resendCalls, 1);
      expect(cubit.state.feedback, AuthFeedback.verificationResent);

      await cubit.checkEmailVerified();
      expect(cubit.state.feedback, AuthFeedback.emailNotVerifiedYet);

      repo.currentUser = _userA;
      repo.linkedUserId = _userA.id;
      await cubit.checkEmailVerified();
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.user, _userA);
    });
  });

  group('AuthCubit stream and password recovery', () {
    test('handles passwordRecovery routing flag, updatePassword, and stream failures', () async {
      final repo = FakeCubitAuthRepository(linkedUserId: _userA.id);
      final cubit = _buildCubit(repo);
      addTearDown(() async {
        await cubit.close();
        await repo.dispose();
      });

      var routeNotifications = 0;
      cubit.addListener(() => routeNotifications++);
      await cubit.initialize();

      repo.events.add(
        const AuthSessionFailure(AppFailure(AppErrorCode.network)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.feedback, AuthFeedback.networkError);

      repo.currentUser = _userA;
      repo.events.add(const AuthSessionPasswordRecovery(_userA));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.passwordRecovery);
      expect(cubit.state.passwordRecoveryPending, isTrue);
      expect(routeNotifications, 1);

      final updated = await cubit.updatePassword('newpassword1');
      expect(updated, isTrue);
      expect(cubit.state.passwordRecoveryPending, isFalse);
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.feedback, AuthFeedback.passwordUpdated);
      expect(routeNotifications, 2);
    });

    test(
      'sendPasswordReset returns true on success and false on error',
      () async {
        final repo = FakeCubitAuthRepository();
        final cubit = _buildCubit(repo);
        addTearDown(() async {
          await cubit.close();
          await repo.dispose();
        });
        await cubit.initialize();

        expect(await cubit.sendPasswordReset(_userA.email), isTrue);
        expect(cubit.state.feedback, AuthFeedback.passwordResetSent);

        repo.resetResult = const Left(AppFailure(AppErrorCode.network));
        expect(await cubit.sendPasswordReset(_userA.email), isFalse);
        expect(cubit.state.feedback, AuthFeedback.networkError);
      },
    );
  });
}
