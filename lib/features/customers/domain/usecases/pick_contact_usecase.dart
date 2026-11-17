import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/picked_contact.dart';
import '../repositories/customer_repository.dart';

class PickContactUseCase {
  const PickContactUseCase(this._repository);
  final CustomerRepository _repository;

  Future<Either<AppFailure, PickedContact?>> call() =>
      _repository.pickContact();
}
