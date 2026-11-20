import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_statement_entity.dart';
import '../entities/statement_date_range.dart';
import '../repositories/statement_repository.dart';

class GetCustomerStatementUseCase {
  const GetCustomerStatementUseCase(this._repository);

  final StatementRepository _repository;

  Future<Either<AppFailure, CustomerStatementEntity?>> call(
    String customerId, {
    StatementDateRange range = StatementDateRange.all,
  }) => _repository.getCustomerStatement(customerId, range: range);
}
