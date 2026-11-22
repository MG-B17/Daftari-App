import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/auth_outcome.dart';
import '../entities/auth_user.dart';
import '../entities/ledger_link_status.dart';
import '../repositories/auth_repository.dart';

/// Enforces account-isolation and deliberate first-time ledger linking rules
/// after an authenticated [user] session is established.
Future<Either<AppFailure, AuthOutcome>> evaluateAuthenticatedUser(
  AuthRepository repository,
  AuthUser user,
) async {
  if (!user.emailVerified) {
    return Right(AuthEmailVerificationRequired(email: user.email));
  }

  final statusResult = await repository.getLedgerLinkStatus(user.id);
  return statusResult.fold(
    (failure) async {
      await repository.signOut(expectedUserId: user.id);
      return Left(failure);
    },
    (status) async {
      switch (status) {
        case LedgerLinkStatus.linkedToCurrentUser:
          return Right(AuthSignedIn(user: user));
        case LedgerLinkStatus.linkedToOtherUser:
          final signOutResult = await repository.signOut(
            expectedUserId: user.id,
          );
          return signOutResult.fold(
            Left.new,
            (_) => const Right(AuthAccountMismatchBlocked()),
          );
        case LedgerLinkStatus.unlinked:
          final localDataResult = await repository.hasLocalLedgerData();
          return localDataResult.fold(
            (failure) async {
              await repository.signOut(expectedUserId: user.id);
              return Left(failure);
            },
            (hasLocalData) => Right(
              AuthLinkConfirmationRequired(
                user: user,
                hasLocalData: hasLocalData,
              ),
            ),
          );
      }
    },
  );
}
