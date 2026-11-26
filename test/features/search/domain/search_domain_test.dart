import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/search/domain/repositories/search_repository.dart';
import 'package:daftariapp/features/search/domain/usecases/customer_search_matcher.dart';
import 'package:daftariapp/features/search/domain/usecases/watch_search_customers_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final _now = DateTime.utc(2026, 1, 1);

final _customers = [
  CustomerEntity(
    id: '1',
    name: 'Mohamed Shop 55',
    phone: '01012345678',
    notes: null,
    balancePiasters: 1000,
    createdAt: _now,
    updatedAt: _now,
  ),
  CustomerEntity(
    id: '2',
    name: 'أم كريم',
    phone: null,
    notes: null,
    balancePiasters: 0,
    createdAt: _now,
    updatedAt: _now,
  ),
];

class _StubSearchRepository implements SearchRepository {
  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchSearchableCustomers() =>
      Stream.value(Right(_customers));
}

void main() {
  test(
    'WatchSearchCustomersUseCase delegates stream and filters queries',
    () async {
      final useCase = WatchSearchCustomersUseCase(_StubSearchRepository());
      final first = await useCase().first;
      expect(first.getOrElse((_) => const []), _customers);

      expect(useCase.filter(_customers, ''), isEmpty);
      expect(useCase.filter(_customers, '   '), isEmpty);
      expect(useCase.filter(_customers, 'mohamed'), [_customers.first]);
      expect(useCase.filter(_customers, '٥٥'), [_customers.first]);
      expect(useCase.filter(_customers, '٠١٠١٢٣'), [_customers.first]);
      expect(useCase.filter(_customers, 'كريم'), [_customers.last]);
      expect(useCase.filter(_customers, 'unknown'), isEmpty);
    },
  );

  test('CustomerSearchMatcher normalizes digits, casing, and whitespace', () {
    expect(CustomerSearchMatcher.normalizeQuery('  AbC ٠١٢  '), 'abc 012');
    expect(CustomerSearchMatcher.matches(_customers.first, ''), isTrue);
    expect(CustomerSearchMatcher.matches(_customers.last, '010'), isFalse);
  });
}
