import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_statement_entity.dart';
import '../entities/statement_date_range.dart';

abstract interface class StatementRepository {
  // Returns null for a missing or soft-deleted customer; excludes deleted entries.
  Future<Either<AppFailure, CustomerStatementEntity?>> getCustomerStatement(
    String customerId, {
    StatementDateRange range = StatementDateRange.all,
  });
}
