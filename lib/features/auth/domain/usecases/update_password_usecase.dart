import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/auth_repository.dart';
import 'auth_validation.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<AppFailure, void>> call(String newPassword) {
    final failure = AuthValidation.validatePassword(newPassword);
    if (failure != null) return Future.value(Left(failure));
    return _repository.updatePassword(newPassword);
  }
}
