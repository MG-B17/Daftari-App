import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class WatchCustomersUseCase {
  const WatchCustomersUseCase(this._repository);
  final CustomerRepository _repository;

  Stream<Either<AppFailure, List<CustomerEntity>>> call({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) => _repository.watchCustomers(query: query, filter: filter, sort: sort);
}
