import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../entities/auth_outcome.dart';
import '../entities/auth_user.dart';
import '../entities/ledger_link_status.dart';
import '../repositories/auth_repository.dart';

class ConfirmLedgerLinkUseCase {
  const ConfirmLedgerLinkUseCase(this._repository);

  final AuthRepository _repository;

  /// Completes or cancels deliberate first-time linking of the local ledger to
  /// [user]. Canceling signs out immediately and returns `Right(null)`.
  ///
  /// Re-validates the active session before linking so a stale confirmation
  /// cannot bind the ledger after sign-out or a session change.
  Future<Either<AppFailure, AuthOutcome?>> call({
    required AuthUser user,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      final signOutResult = await _repository.signOut(expectedUserId: user.id);
      return signOutResult.fold(Left.new, (_) => const Right(null));
    }

    if (!user.emailVerified) {
      return Right(AuthEmailVerificationRequired(email: user.email));
    }

    final currentUserResult = await _repository.getCurrentUser();
    return currentUserResult.fold(Left.new, (currentUser) async {
      if (currentUser == null || currentUser.id != user.id) {
        return const Left(AppFailure(AppErrorCode.auth));
      }
      if (!currentUser.emailVerified) {
        return Right(AuthEmailVerificationRequired(email: currentUser.email));
      }

      final linkResult = await _repository.linkLedgerToUser(currentUser.id);
      return linkResult.fold(Left.new, (status) async {
        final latestUserResult = await _repository.getCurrentUser();
        return latestUserResult.fold(Left.new, (latestUser) async {
          if (latestUser == null || latestUser.id != user.id) {
            return const Left(AppFailure(AppErrorCode.auth));
          }
          if (!latestUser.emailVerified) {
            return Right(
              AuthEmailVerificationRequired(email: latestUser.email),
            );
          }

          switch (status) {
            case LedgerLinkStatus.linkedToCurrentUser:
              return Right(AuthSignedIn(user: latestUser));
            case LedgerLinkStatus.linkedToOtherUser:
              final signOutResult = await _repository.signOut(
                expectedUserId: user.id,
              );
              return signOutResult.fold(
                Left.new,
                (_) => const Right(AuthAccountMismatchBlocked()),
              );
            case LedgerLinkStatus.unlinked:
              return const Left(AppFailure(AppErrorCode.storage));
          }
        });
      });
    });
  }
}
