import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/usecases/auth_validation.dart';
import '../repositories/forgot_password_repository.dart';

class SendPasswordResetUseCase {
  const SendPasswordResetUseCase(this._repository);

  final ForgotPasswordRepository _repository;

  Future<Either<AppFailure, void>> call(String email) {
    final failure = AuthValidation.validateEmail(email);
    if (failure != null) return Future.value(Left(failure));
    return _repository.sendPasswordResetEmail(email.trim());
  }
}
