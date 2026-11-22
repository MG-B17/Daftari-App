import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/auth_outcome.dart';
import '../repositories/auth_repository.dart';
import 'auth_validation.dart';
import 'ledger_link_evaluator.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

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
      (user) => evaluateAuthenticatedUser(_repository, user),
    );
  }
}
