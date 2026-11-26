import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/search/domain/repositories/search_repository.dart';
import 'package:daftariapp/features/search/domain/usecases/watch_search_customers_usecase.dart';
import 'package:daftariapp/features/search/presentation/cubit/search_cubit.dart';
import 'package:daftariapp/features/search/presentation/cubit/search_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final _t1 = DateTime.utc(2025, 1, 1);
final _t2 = DateTime.utc(2026, 1, 1);

final _alice = CustomerEntity(
  id: 'a',
  name: 'Alice Shop 99',
  phone: '01012345678',
  notes: null,
  balancePiasters: 0,
  createdAt: _t1,
  updatedAt: _t1,
);

final _bob = CustomerEntity(
  id: 'b',
  name: 'أحمد الشناوي',
  phone: '01124567890',
  notes: 'Workshop',
  balancePiasters: 25000,
  createdAt: _t2,
  updatedAt: _t2,
);

const _databaseFailure = AppFailure(AppErrorCode.database);

class _FakeSearchRepository implements SearchRepository {
  final customers =
      StreamController<Either<AppFailure, List<CustomerEntity>>>.broadcast();

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchSearchableCustomers() =>
      customers.stream;

  Future<void> dispose() => customers.close();
}

void main() {
  late _FakeSearchRepository repository;

  setUp(() => repository = _FakeSearchRepository());
  tearDown(() => repository.dispose());

  SearchCubit buildCubit() =>
      SearchCubit(WatchSearchCustomersUseCase(repository));

  blocTest<SearchCubit, SearchState>(
    'loads active customers, keeps empty query results empty, and updates live',
    build: buildCubit,
    act: (cubit) async {
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.hasQuery, isFalse);
      expect(cubit.state.results, isEmpty);
      await cubit.load();
      repository.customers.add(Right([_alice, _bob]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.hasQuery, isFalse);
      expect(cubit.state.results, isEmpty);
      cubit.setQuery('   ');
      expect(cubit.state.hasQuery, isFalse);
      expect(cubit.state.results, isEmpty);
      cubit.setQuery('alice');
      expect(cubit.state.results, [_alice]);
      // Simulate customer soft-delete removing Alice from active stream.
      repository.customers.add(Right([_bob]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.results, isEmpty);
    },
    verify: (_) => expect(repository.customers.hasListener, isFalse),
  );

  blocTest<SearchCubit, SearchState>(
    'matches by name, Western digits, Arabic-Indic digits, and clears query',
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      repository.customers.add(Right([_alice, _bob]));
      await Future<void>.delayed(Duration.zero);

      cubit.setQuery('  ALICE  ');
      expect(cubit.state.results, [_alice]);

      cubit.setQuery('٩٩');
      expect(cubit.state.results, [_alice]);

      cubit.setQuery('٠١١٢٤٥');
      expect(cubit.state.results, [_bob]);

      cubit.setQuery('011245');
      expect(cubit.state.results, [_bob]);

      cubit.setQuery('الشناوي');
      expect(cubit.state.results, [_bob]);

      cubit.setQuery('does not exist');
      expect(cubit.state.hasQuery, isTrue);
      expect(cubit.state.results, isEmpty);

      cubit.clearQuery();
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.hasQuery, isFalse);
      expect(cubit.state.results, isEmpty);
    },
  );

  blocTest<SearchCubit, SearchState>(
    'surfaces stream failures and recovers on reload',
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      repository.customers.add(const Left(_databaseFailure));
      await Future<void>.delayed(Duration.zero);
      await cubit.load();
      repository.customers.add(Right([_alice]));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const SearchState(loading: true),
      const SearchState(loading: false, failure: _databaseFailure),
      const SearchState(loading: true),
      SearchState(loading: false, customers: [_alice]),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'maps raw stream error to unexpected failure',
    build: buildCubit,
    act: (cubit) async {
      await cubit.load();
      repository.customers.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const SearchState(loading: true),
      const SearchState(
        loading: false,
        failure: AppFailure(AppErrorCode.unexpected),
      ),
    ],
  );
}
