import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_validation.dart';

class CreateTransactionUseCase {
  const CreateTransactionUseCase(this._repository);
  final TransactionRepository _repository;

  Future<Either<AppFailure, TransactionEntity>> call({
    required String customerId,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) {
    final failure = TransactionValidation.validate(
      amountPiasters: amountPiasters,
    );
    if (failure != null) return Future.value(Left(failure));
    return _repository.createTransaction(
      customerId: customerId,
      type: type,
      amountPiasters: amountPiasters,
      transactionDate: transactionDate,
      note: note,
    );
  }
}
