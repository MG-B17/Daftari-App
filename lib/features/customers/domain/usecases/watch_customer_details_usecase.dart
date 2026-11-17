import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class WatchCustomerDetailsUseCase {
  const WatchCustomerDetailsUseCase(this._repository);
  final CustomerRepository _repository;

  Stream<Either<AppFailure, CustomerEntity?>> call(String id) =>
      _repository.watchCustomerDetails(id);
}
