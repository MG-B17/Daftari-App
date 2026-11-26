import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../customers/domain/entities/customer_entity.dart';

abstract interface class SearchRepository {
  /// Emits active customers with derived balances whenever customer or
  /// transaction data changes, surfacing failures without closing the stream.
  Stream<Either<AppFailure, List<CustomerEntity>>> watchSearchableCustomers();
}
