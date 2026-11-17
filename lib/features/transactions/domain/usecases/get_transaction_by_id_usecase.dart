import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionByIdUseCase {
  const GetTransactionByIdUseCase(this._repository);
  final TransactionRepository _repository;

  Future<Either<AppFailure, TransactionEntity?>> call(String id) =>
      _repository.getTransactionById(id);
}
