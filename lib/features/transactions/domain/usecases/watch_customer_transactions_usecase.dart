import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class WatchCustomerTransactionsUseCase {
  const WatchCustomerTransactionsUseCase(this._repository);
  final TransactionRepository _repository;

  Stream<Either<AppFailure, List<TransactionEntity>>> call(String customerId) =>
      _repository.watchCustomerTransactions(customerId);
}
