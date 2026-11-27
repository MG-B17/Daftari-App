import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/date/date_service.dart';
import '../../../customers/data/mappers/customer_mapper.dart';
import '../../../transactions/data/mappers/transaction_mapper.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/entities/statement_date_range.dart';
import '../../domain/repositories/statement_repository.dart';

class StatementRepositoryImpl implements StatementRepository {
  const StatementRepositoryImpl(
    this._customers,
    this._transactions,
    this._dates,
    this._errors,
  );

  final CustomerDao _customers;
  final TransactionDao _transactions;
  final DateService _dates;
  final ErrorHandler _errors;

  @override
  Future<Either<AppFailure, CustomerStatementEntity?>> getCustomerStatement(
    String customerId, {
    StatementDateRange range = StatementDateRange.all,
  }) async {
    try {
      // Both DAOs use the same database, giving the preview one consistent snapshot.
      final statement = await _customers.transaction(() async {
        final customer = await _customers.getCustomerById(customerId);
        if (customer == null) return null;
        final records = await _transactions.getCustomerTransactions(customerId);
        final ledger = records.map(TransactionMapper.toEntity).toList();
        final balance = ledger.fold<int>(
          0,
          (total, entry) =>
              total +
              (entry.type == TransactionType.credit
                  ? entry.amountPiasters
                  : -entry.amountPiasters),
        );
        return CustomerStatementEntity.fromLedger(
          customer: CustomerMapper.toEntity(customer, balance),
          activeTransactions: ledger,
          generatedAt: _dates.now(),
          range: range,
        );
      });
      return Right(statement);
    } catch (error) {
      return Left(await _errors.handle(error));
    }
  }
}
