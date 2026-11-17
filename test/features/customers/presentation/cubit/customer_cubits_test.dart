import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/entities/picked_contact.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/create_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/pick_contact_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/update_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customer_details_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_form_cubit.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customers_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final _old = DateTime.utc(2025);
final _new = DateTime.utc(2026);
final _alice = CustomerEntity(
  id: 'a',
  name: 'Alice',
  phone: '01012345678',
  notes: null,
  balancePiasters: 0,
  createdAt: _old,
  updatedAt: _old,
);
final _bob = CustomerEntity(
  id: 'b',
  name: 'Bob',
  phone: '01112345678',
  notes: 'Note',
  balancePiasters: 250,
  createdAt: _new,
  updatedAt: _new,
);
const _databaseFailure = AppFailure(AppErrorCode.database);
const _validationFailure = AppFailure(AppErrorCode.validation);
const _pickerFailure = AppFailure(AppErrorCode.contactPicker);
const _contact = PickedContact(name: 'Picked', phone: '01012345678');

class _Repository implements CustomerRepository {
  final customers =
      StreamController<Either<AppFailure, List<CustomerEntity>>>.broadcast();
  final details =
      StreamController<Either<AppFailure, CustomerEntity?>>.broadcast();
  Either<AppFailure, CustomerEntity> createResult = Right(_alice);
  Either<AppFailure, bool> updateResult = const Right(true);
  Either<AppFailure, PickedContact?> contactResult = const Right(null);
  int creates = 0;
  int updates = 0;
  String? updatedId;

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) => customers.stream;

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) =>
      details.stream;

  @override
  Future<Either<AppFailure, CustomerEntity>> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    creates++;
    return createResult;
  }

  @override
  Future<Either<AppFailure, bool>> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    updates++;
    updatedId = id;
    return updateResult;
  }

  @override
  Future<Either<AppFailure, PickedContact?>> pickContact() async =>
      contactResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> dispose() async {
    await customers.close();
    await details.close();
  }
}

void main() {
  late _Repository repository;
  setUp(() => repository = _Repository());
  tearDown(() => repository.dispose());

  CustomersListCubit listCubit() => CustomersListCubit(
    WatchCustomersUseCase(repository),
    PickContactUseCase(repository),
  );
  CustomerFormCubit formCubit() => CustomerFormCubit(
    CreateCustomerUseCase(repository),
    UpdateCustomerUseCase(repository),
    WatchCustomerDetailsUseCase(repository),
    PickContactUseCase(repository),
  );

  blocTest<CustomersListCubit, CustomersListState>(
    'loads and receives live updates with unfiltered summary figures',
    build: listCubit,
    act: (cubit) async {
      expect(cubit.state.loading, isTrue);
      await cubit.load();
      repository.customers.add(Right([_alice, _bob]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.owing, 1);
      expect(cubit.state.settled, 1);
      expect(cubit.state.totalDebt, 250);
      repository.customers.add(Right([_bob]));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const CustomersListState(),
      CustomersListState(loading: false, customers: [_alice, _bob]),
      CustomersListState(loading: false, customers: [_bob]),
    ],
    verify: (_) => expect(repository.customers.hasListener, isFalse),
  );

  blocTest<CustomersListCubit, CustomersListState>(
    'searches normalized digits, filters and sorts without changing totals',
    build: listCubit,
    act: (cubit) async {
      await cubit.load();
      repository.customers.add(Right([_alice, _bob]));
      await Future<void>.delayed(Duration.zero);
      cubit.setQuery('٠١١');
      expect(cubit.state.visible, [_bob]);
      cubit.setQuery('');
      cubit.setFilter(CustomerFilter.settled);
      expect(cubit.state.visible, [_alice]);
      cubit.setFilter(CustomerFilter.owes);
      expect(cubit.state.visible, [_bob]);
      cubit.setFilter(CustomerFilter.all);
      cubit.setSort(CustomerSort.balanceDesc);
      expect(cubit.state.visible, [_bob, _alice]);
      cubit.setSort(CustomerSort.recent);
      expect(cubit.state.visible, [_bob, _alice]);
      cubit.setSort(CustomerSort.nameAsc);
      expect(cubit.state.visible, [_alice, _bob]);
      expect(cubit.state.totalDebt, 250);
    },
    expect: () => [
      const CustomersListState(),
      isA<CustomersListState>().having((s) => s.customers.length, 'count', 2),
      isA<CustomersListState>().having((s) => s.query, 'query', '٠١١'),
      isA<CustomersListState>().having((s) => s.query, 'query', ''),
      isA<CustomersListState>().having(
        (s) => s.filter,
        'filter',
        CustomerFilter.settled,
      ),
      isA<CustomersListState>().having(
        (s) => s.filter,
        'filter',
        CustomerFilter.owes,
      ),
      isA<CustomersListState>().having(
        (s) => s.filter,
        'filter',
        CustomerFilter.all,
      ),
      isA<CustomersListState>().having(
        (s) => s.sort,
        'sort',
        CustomerSort.balanceDesc,
      ),
      isA<CustomersListState>().having(
        (s) => s.sort,
        'sort',
        CustomerSort.recent,
      ),
      isA<CustomersListState>().having(
        (s) => s.sort,
        'sort',
        CustomerSort.nameAsc,
      ),
    ],
  );

  blocTest<CustomersListCubit, CustomersListState>(
    'surfaces stream failures',
    build: listCubit,
    act: (cubit) async {
      await cubit.load();
      repository.customers.add(const Left(_databaseFailure));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const CustomersListState(),
      const CustomersListState(loading: false, failure: _databaseFailure),
    ],
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'preloads and observes updates and cancels the details subscription',
    build: formCubit,
    act: (cubit) async {
      await cubit.load('a');
      repository.details.add(Right(_alice));
      await Future<void>.delayed(Duration.zero);
      repository.details.add(Right(_bob));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const CustomerFormState(loading: true),
      CustomerFormState(customer: _alice),
      CustomerFormState(customer: _bob),
    ],
    verify: (_) => expect(repository.details.hasListener, isFalse),
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'creates a valid customer',
    build: formCubit,
    act: (cubit) => cubit.save(name: 'Alice', phone: '01012345678'),
    expect: () => [
      const CustomerFormState(saving: true),
      const CustomerFormState(saved: true),
    ],
    verify: (_) => expect(repository.creates, 1),
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'rejects invalid input without writing',
    build: formCubit,
    act: (cubit) => cubit.save(name: '', phone: 'bad'),
    expect: () => [
      const CustomerFormState(saving: true),
      const CustomerFormState(failure: _validationFailure),
    ],
    verify: (_) => expect(repository.creates, 0),
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'surfaces create failures',
    setUp: () => repository.createResult = const Left(_databaseFailure),
    build: formCubit,
    act: (cubit) => cubit.save(name: 'Alice'),
    expect: () => [
      const CustomerFormState(saving: true),
      const CustomerFormState(failure: _databaseFailure),
    ],
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'updates the loaded customer',
    build: formCubit,
    act: (cubit) async {
      await cubit.load('a');
      repository.details.add(Right(_alice));
      await Future<void>.delayed(Duration.zero);
      await cubit.save(name: 'Changed');
    },
    expect: () => [
      const CustomerFormState(loading: true),
      CustomerFormState(customer: _alice),
      CustomerFormState(customer: _alice, saving: true),
      CustomerFormState(customer: _alice, saved: true),
    ],
    verify: (_) {
      expect(repository.updates, 1);
      expect(repository.updatedId, 'a');
    },
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'surfaces update failure and retains preloaded customer',
    setUp: () => repository.updateResult = const Left(_databaseFailure),
    build: formCubit,
    act: (cubit) async {
      await cubit.load('a');
      repository.details.add(Right(_alice));
      await Future<void>.delayed(Duration.zero);
      await cubit.save(name: 'Alice');
    },
    expect: () => [
      const CustomerFormState(loading: true),
      CustomerFormState(customer: _alice),
      CustomerFormState(customer: _alice, saving: true),
      CustomerFormState(customer: _alice, failure: _databaseFailure),
    ],
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'surfaces edit preload stream failure',
    build: formCubit,
    act: (cubit) async {
      await cubit.load('a');
      repository.details.add(const Left(_databaseFailure));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const CustomerFormState(loading: true),
      const CustomerFormState(failure: _databaseFailure),
    ],
  );

  blocTest<CustomerFormCubit, CustomerFormState>(
    'validates updates before calling the repository',
    build: formCubit,
    act: (cubit) async {
      await cubit.load('a');
      repository.details.add(Right(_alice));
      await Future<void>.delayed(Duration.zero);
      await cubit.save(name: 'Alice', phone: 'invalid');
    },
    expect: () => [
      const CustomerFormState(loading: true),
      CustomerFormState(customer: _alice),
      CustomerFormState(customer: _alice, saving: true),
      CustomerFormState(customer: _alice, failure: _validationFailure),
    ],
    verify: (_) => expect(repository.updates, 0),
  );

  for (final result in <Either<AppFailure, PickedContact?>>[
    const Right(_contact),
    const Right(null),
    const Left(_pickerFailure),
  ]) {
    blocTest<CustomersListCubit, CustomersListState>(
      'list forwards picker result $result',
      setUp: () => repository.contactResult = result,
      build: listCubit,
      act: (cubit) async => expect(await cubit.pickContact(), result),
      expect: () => [],
    );
    blocTest<CustomerFormCubit, CustomerFormState>(
      'form forwards picker result $result',
      setUp: () => repository.contactResult = result,
      build: formCubit,
      act: (cubit) async => expect(await cubit.pickContact(), result),
      expect: () => [],
    );
  }
}
