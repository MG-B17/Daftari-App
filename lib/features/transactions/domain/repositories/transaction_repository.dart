import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/transaction_entity.dart';

abstract interface class TransactionRepository {
  Stream<Either<AppFailure, List<TransactionEntity>>> watchCustomerTransactions(
    String customerId,
  );

  Future<Either<AppFailure, TransactionEntity?>> getTransactionById(String id);

  Future<Either<AppFailure, TransactionEntity>> createTransaction({
    required String customerId,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  });

  Future<Either<AppFailure, TransactionEntity>> editTransaction({
    required String id,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  });

  Future<Either<AppFailure, bool>> softDeleteTransaction(String id);
}
