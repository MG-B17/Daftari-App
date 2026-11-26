import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../repositories/search_repository.dart';
import 'customer_search_matcher.dart';

class WatchSearchCustomersUseCase {
  const WatchSearchCustomersUseCase(this._repository);

  final SearchRepository _repository;

  Stream<Either<AppFailure, List<CustomerEntity>>> call() =>
      _repository.watchSearchableCustomers();

  List<CustomerEntity> filter(List<CustomerEntity> customers, String query) =>
      CustomerSearchMatcher.filter(customers, query);
}
