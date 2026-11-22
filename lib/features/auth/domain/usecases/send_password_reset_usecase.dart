import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/auth_repository.dart';
import 'auth_validation.dart';

class SendPasswordResetUseCase {
  const SendPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<AppFailure, void>> call(String email) {
    final failure = AuthValidation.validateEmail(email);
    if (failure != null) return Future.value(Left(failure));
    return _repository.sendPasswordResetEmail(email.trim());
  }
}
