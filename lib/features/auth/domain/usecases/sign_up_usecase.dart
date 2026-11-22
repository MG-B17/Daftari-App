import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/auth_outcome.dart';
import '../repositories/auth_repository.dart';
import 'auth_validation.dart';
import 'ledger_link_evaluator.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

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
      (user) => evaluateAuthenticatedUser(_repository, user),
    );
  }
}
