import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/entities/picked_contact.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/create_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/pick_contact_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/soft_delete_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/update_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customer_details_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final now = DateTime.utc(2026);
final customer = CustomerEntity(
  id: '1',
  name: 'Name',
  phone: null,
  notes: null,
  balancePiasters: 100,
  createdAt: now,
  updatedAt: now,
);
const failure = AppFailure(AppErrorCode.database);
const validationFailure = AppFailure(AppErrorCode.validation);

class FakeCustomerRepository implements CustomerRepository {
  int writes = 0;
  Object? arguments;
  Either<AppFailure, CustomerEntity> createResult = Right(customer);
  Either<AppFailure, bool> writeResult = const Right(true);
  Either<AppFailure, PickedContact?> contactResult = const Right(null);
  List<Either<AppFailure, List<CustomerEntity>>> lists = [
    Right([customer]),
  ];
  List<Either<AppFailure, CustomerEntity?>> details = [Right(customer)];

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) {
    arguments = (query, filter, sort);
    return Stream.fromIterable(lists);
  }

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) {
    arguments = id;
    return Stream.fromIterable(details);
  }

  @override
  Future<Either<AppFailure, CustomerEntity>> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    writes++;
    arguments = (name, phone, notes);
    return createResult;
  }

  @override
  Future<Either<AppFailure, bool>> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    writes++;
    arguments = (id, name, phone, notes);
    return writeResult;
  }

  @override
  Future<Either<AppFailure, bool>> softDeleteCustomer(String id) async {
    arguments = id;
    return writeResult;
  }

  @override
  Future<Either<AppFailure, PickedContact?>> pickContact() async =>
      contactResult;
}

void main() {
  late FakeCustomerRepository repository;
  setUp(() => repository = FakeCustomerRepository());

  test('entity equality includes all fields', () {
    expect(
      customer,
      CustomerEntity(
        id: '1',
        name: 'Name',
        phone: null,
        notes: null,
        balancePiasters: 100,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(
      customer,
      isNot(
        CustomerEntity(
          id: '1',
          name: 'Name',
          phone: null,
          notes: null,
          balancePiasters: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    expect(
      const PickedContact(name: 'A', phone: null),
      const PickedContact(name: 'A', phone: null),
    );
  });

  test('watch customers forwards options and all results', () async {
    repository.lists = [
      Right([customer]),
      const Left(failure),
      const Right([]),
    ];
    final stream = WatchCustomersUseCase(repository)(
      query: 'abc',
      filter: CustomerFilter.owes,
      sort: CustomerSort.recent,
    );
    expect(repository.arguments, (
      'abc',
      CustomerFilter.owes,
      CustomerSort.recent,
    ));
    expect(await stream.toList(), repository.lists);
    WatchCustomersUseCase(repository)();
    expect(repository.arguments, (
      '',
      CustomerFilter.all,
      CustomerSort.nameAsc,
    ));
  });

  test('watch details forwards id, missing value and failures', () async {
    repository.details = [
      Right(customer),
      const Right(null),
      const Left(failure),
    ];
    final stream = WatchCustomerDetailsUseCase(repository)('1');
    expect(repository.arguments, '1');
    expect(await stream.toList(), repository.details);
  });

  for (final invalid in [('', null), ('   ', '01012345678'), ('Name', '123')]) {
    test('create and update reject invalid input $invalid', () async {
      expect(
        await CreateCustomerUseCase(repository)(
          name: invalid.$1,
          phone: invalid.$2,
        ),
        const Left<AppFailure, CustomerEntity>(validationFailure),
      );
      expect(
        await UpdateCustomerUseCase(repository)(
          id: '1',
          name: invalid.$1,
          phone: invalid.$2,
        ),
        const Left<AppFailure, bool>(validationFailure),
      );
      expect(repository.writes, 0);
    });
  }

  test(
    'create accepts optional phone and forwards repository result',
    () async {
      expect(
        await CreateCustomerUseCase(repository)(name: 'Name', notes: 'note'),
        Right(customer),
      );
      expect(repository.arguments, ('Name', null, 'note'));
      repository.createResult = const Left(failure);
      expect(
        await CreateCustomerUseCase(repository)(
          name: 'Name',
          phone: '٠١٠١٢٣٤٥٦٧٨',
        ),
        const Left<AppFailure, CustomerEntity>(failure),
      );
    },
  );

  test('update forwards values and success or failure', () async {
    expect(
      await UpdateCustomerUseCase(repository)(
        id: '1',
        name: 'Name',
        phone: '+201012345678',
        notes: 'note',
      ),
      const Right<AppFailure, bool>(true),
    );
    expect(repository.arguments, ('1', 'Name', '+201012345678', 'note'));
    repository.writeResult = const Left(failure);
    expect(
      await UpdateCustomerUseCase(repository)(id: '1', name: 'Name', phone: ''),
      const Left<AppFailure, bool>(failure),
    );
  });

  test('delete forwards id, missing result and failure', () async {
    repository.writeResult = const Right(false);
    expect(
      await SoftDeleteCustomerUseCase(repository)('missing'),
      const Right<AppFailure, bool>(false),
    );
    expect(repository.arguments, 'missing');
    repository.writeResult = const Left(failure);
    expect(
      await SoftDeleteCustomerUseCase(repository)('1'),
      const Left<AppFailure, bool>(failure),
    );
  });

  test('contact picker forwards selection, cancellation and failure', () async {
    final pick = PickContactUseCase(repository);
    expect(await pick(), const Right<AppFailure, PickedContact?>(null));
    const contact = PickedContact(name: 'Name', phone: '01012345678');
    repository.contactResult = const Right(contact);
    expect(await pick(), const Right<AppFailure, PickedContact?>(contact));
    repository.contactResult = const Left(failure);
    expect(await pick(), const Left<AppFailure, PickedContact?>(failure));
  });
}
