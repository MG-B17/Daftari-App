import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/usecases/auth_validation.dart';
import '../repositories/update_password_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final UpdatePasswordRepository _repository;

  Future<Either<AppFailure, void>> call(String newPassword) {
    final failure = AuthValidation.validatePassword(newPassword);
    if (failure != null) return Future.value(Left(failure));
    return _repository.updatePassword(newPassword);
  }
}
