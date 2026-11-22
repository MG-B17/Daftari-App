import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/entities/auth_outcome.dart';
import '../../../session/domain/repositories/auth_session_repository.dart';
import '../../../session/domain/usecases/auth_validation.dart';
import '../../../session/domain/usecases/ledger_link_evaluator.dart';
import '../repositories/sign_up_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository, this._sessionRepository);

  final SignUpRepository _repository;
  final AuthSessionRepository _sessionRepository;

  Future<Either<AppFailure, AuthOutcome>> call({
    required String email,
    required String password,
    required String shopName,
  }) async {
    final failure = AuthValidation.validateSignUp(
      email: email,
      password: password,
      shopName: shopName,
    );
    if (failure != null) return Left(failure);

    final result = await _repository.signUpWithPassword(
      email: email.trim(),
      password: password,
      shopName: shopName.trim(),
    );
    return result.fold(
      Left.new,
      (user) => evaluateAuthenticatedUser(_sessionRepository, user),
    );
  }
}
