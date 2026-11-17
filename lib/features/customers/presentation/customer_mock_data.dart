import '../../../l10n/generated/app_localizations.dart';

class CustomerMock {
  const CustomerMock(this.id, this.name, this.phone, this.balance);

  final String id;
  final String name;
  final String phone;
  final int balance;
}

List<CustomerMock> mockCustomers(AppLocalizations l10n) => [
  CustomerMock('1', l10n.customersSample1, '01012345678', 320000),
  CustomerMock('2', l10n.customersSample2, '01124567890', 245000),
  CustomerMock('3', l10n.customersSample3, '01234567891', 185000),
  CustomerMock('4', l10n.customersSample4, '01098765432', 78000),
  CustomerMock('5', l10n.customersSample5, '01155443322', 0),
  CustomerMock('6', l10n.customersSample6, '01288776655', 92000),
  CustomerMock('7', l10n.customersSample7, '01066778899', 0),
];

CustomerMock? mockCustomerById(AppLocalizations l10n, String id) {
  for (final customer in mockCustomers(l10n)) {
    if (customer.id == id) return customer;
  }
  return null;
}
