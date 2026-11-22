import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../repositories/auth_session_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthSessionRepository _repository;

  /// Signs out without clearing local ledger data or persisted ledger ownership.
  Future<Either<AppFailure, void>> call() => _repository.signOut();
}
