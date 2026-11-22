import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/entities/auth_outcome.dart';
import '../../../session/domain/repositories/auth_session_repository.dart';
import '../../../session/domain/usecases/ledger_link_evaluator.dart';
import '../repositories/verify_email_repository.dart';

class CheckEmailVerifiedUseCase {
  const CheckEmailVerifiedUseCase(this._repository, this._sessionRepository);

  final VerifyEmailRepository _repository;
  final AuthSessionRepository _sessionRepository;

  /// Checks whether the current session user has verified their email.
  ///
  /// Returns `Right(null)` when no verified session is active yet; otherwise
  /// evaluates ledger ownership and returns the resulting [AuthOutcome].
  Future<Either<AppFailure, AuthOutcome?>> call() async {
    final result = await _repository.getCurrentUser();
    return result.fold(Left.new, (user) async {
      if (user == null || !user.emailVerified) {
        return const Right(null);
      }
      return evaluateAuthenticatedUser(_sessionRepository, user);
    });
  }
}
