import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/customer_entity.dart';
import '../entities/picked_contact.dart';

abstract interface class CustomerRepository {
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  });

  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id);

  Future<Either<AppFailure, CustomerEntity>> createCustomer({
    required String name,
    String? phone,
    String? notes,
  });

  Future<Either<AppFailure, bool>> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  });

  Future<Either<AppFailure, bool>> softDeleteCustomer(String id);

  Future<Either<AppFailure, PickedContact?>> pickContact();
}
