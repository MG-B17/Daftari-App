import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/entities/auth_outcome.dart';
import '../../../session/domain/repositories/auth_session_repository.dart';
import '../../../session/domain/usecases/auth_validation.dart';
import '../../../session/domain/usecases/ledger_link_evaluator.dart';
import '../repositories/login_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository, this._sessionRepository);

  final LoginRepository _repository;
  final AuthSessionRepository _sessionRepository;

  Future<Either<AppFailure, AuthOutcome>> call({
    required String email,
    required String password,
  }) async {
    final failure = AuthValidation.validateSignIn(
      email: email,
      password: password,
    );
    if (failure != null) return Left(failure);

    final result = await _repository.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return result.fold(
      Left.new,
      (user) => evaluateAuthenticatedUser(_sessionRepository, user),
    );
  }
}
