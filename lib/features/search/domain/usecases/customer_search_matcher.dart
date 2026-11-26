import '../../../../core/extensions/string_extensions.dart';
import '../../../customers/domain/entities/customer_entity.dart';

abstract final class CustomerSearchMatcher {
  static String normalizeQuery(String query) =>
      query.trim().toLowerCase().toWesternDigits;

  static bool matches(CustomerEntity customer, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return customer.name.toLowerCase().toWesternDigits.contains(
          normalizedQuery,
        ) ||
        (customer.phone?.toWesternDigits.contains(normalizedQuery) ?? false);
  }

  static List<CustomerEntity> filter(
    List<CustomerEntity> customers,
    String query,
  ) {
    final term = normalizeQuery(query);
    if (term.isEmpty) return const [];
    return customers
        .where((customer) => matches(customer, term))
        .toList(growable: false);
  }
}
