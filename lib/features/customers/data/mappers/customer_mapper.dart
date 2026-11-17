import '../../../../core/database/app_database.dart';
import '../../domain/entities/customer_entity.dart';

abstract final class CustomerMapper {
  static CustomerEntity toEntity(Customer customer, int balancePiasters) =>
      CustomerEntity(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        notes: customer.notes,
        balancePiasters: balancePiasters,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      );
}
