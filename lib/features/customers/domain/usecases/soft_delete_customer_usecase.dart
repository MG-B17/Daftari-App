import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/customer_repository.dart';

class SoftDeleteCustomerUseCase {
  const SoftDeleteCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<AppFailure, bool>> call(String id) =>
      _repository.softDeleteCustomer(id);
}
