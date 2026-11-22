import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/usecases/auth_validation.dart';
import '../repositories/verify_email_repository.dart';

class ResendVerificationEmailUseCase {
  const ResendVerificationEmailUseCase(this._repository);

  final VerifyEmailRepository _repository;

  Future<Either<AppFailure, void>> call(String email) {
    final failure = AuthValidation.validateEmail(email);
    if (failure != null) return Future.value(Left(failure));
    return _repository.resendVerificationEmail(email.trim());
  }
}
