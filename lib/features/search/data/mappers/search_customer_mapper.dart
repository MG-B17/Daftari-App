import '../../../../core/database/app_database.dart';
import '../../../customers/domain/entities/customer_entity.dart';

abstract final class SearchCustomerMapper {
  static CustomerEntity toEntity(CustomerWithBalance row) => CustomerEntity(
    id: row.customer.id,
    name: row.customer.name,
    phone: row.customer.phone,
    notes: row.customer.notes,
    balancePiasters: row.balancePiasters,
    createdAt: row.customer.createdAt,
    updatedAt: row.customer.updatedAt,
  );
}
