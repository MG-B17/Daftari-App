import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../repositories/customer_repository.dart';
import 'customer_validation.dart';

class UpdateCustomerUseCase {
  const UpdateCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<AppFailure, bool>> call({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) {
    final failure = CustomerValidation.validate(name: name, phone: phone);
    if (failure != null) return Future.value(Left(failure));
    return _repository.updateCustomer(
      id: id,
      name: name,
      phone: phone,
      notes: notes,
    );
  }
}
