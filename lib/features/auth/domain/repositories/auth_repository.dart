import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/auth_session_event.dart';
import '../entities/auth_user.dart';
import '../entities/ledger_link_status.dart';

abstract interface class AuthRepository {
  bool get isConfigured;

  Stream<AuthSessionEvent> watchAuthChanges();

  Future<Either<AppFailure, AuthUser?>> getCurrentUser();

  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  });

  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  });

  /// Signs out the active session without deleting local ledger data or
  /// clearing the persisted ledger owner ID.
  ///
  /// When [expectedUserId] is provided, signs out only if the active session
  /// still belongs to [expectedUserId].
  Future<Either<AppFailure, void>> signOut({String? expectedUserId});

  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email);

  Future<Either<AppFailure, void>> resendVerificationEmail(String email);

  Future<Either<AppFailure, void>> updatePassword(String newPassword);

  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  );

  /// Atomically binds the local ledger to [userId] if unlinked.
  ///
  /// Returns [LedgerLinkStatus.linkedToCurrentUser] if newly linked or already
  /// linked to [userId], or [LedgerLinkStatus.linkedToOtherUser] if already
  /// linked to a different account without overwriting it.
  Future<Either<AppFailure, LedgerLinkStatus>> linkLedgerToUser(String userId);

  Future<Either<AppFailure, bool>> hasLocalLedgerData();
}
