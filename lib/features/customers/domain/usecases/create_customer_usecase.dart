import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';
import 'customer_validation.dart';

class CreateCustomerUseCase {
  const CreateCustomerUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<AppFailure, CustomerEntity>> call({
    required String name,
    String? phone,
    String? notes,
  }) {
    final failure = CustomerValidation.validate(name: name, phone: phone);
    if (failure != null) return Future.value(Left(failure));
    return _repository.createCustomer(name: name, phone: phone, notes: notes);
  }
}
