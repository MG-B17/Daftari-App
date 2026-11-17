import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/transaction_repository.dart';

class SoftDeleteTransactionUseCase {
  const SoftDeleteTransactionUseCase(this._repository);
  final TransactionRepository _repository;

  Future<Either<AppFailure, bool>> call(String id) =>
      _repository.softDeleteTransaction(id);
}
