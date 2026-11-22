import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  /// Signs out without clearing local ledger data or persisted ledger ownership.
  Future<Either<AppFailure, void>> call() => _repository.signOut();
}
