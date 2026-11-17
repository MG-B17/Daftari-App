import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/contact_picker_service.dart';
import 'package:daftariapp/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  late AppDatabase db;
  late CustomerRepositoryImpl repository;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = CustomerRepositoryImpl(
      db.customerDao,
      ContactPickerService(pickContact: () async => null),
      ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
    );
  });
  tearDown(() => db.close());

  test(
    'CRUD, filters, sorting, search and details use derived balances',
    () async {
      final a = await db.customerDao.createCustomer(
        name: 'Ahmed',
        phone: '01012345678',
      );
      final b = await db.customerDao.createCustomer(name: 'Basma');
      await db.transactionDao.createTransaction(
        customerId: b.id,
        type: TransactionTypes.credit,
        amountPiasters: 200,
      );
      final list = await repository
          .watchCustomers(sort: CustomerSort.balanceDesc)
          .first;
      final items = list.getOrElse((_) => []);
      expect(items.map((e) => e.name), ['Basma', 'Ahmed']);
      expect(items.map((e) => e.balancePiasters), [200, 0]);
      expect(
        (await repository.watchCustomers(filter: CustomerFilter.owes).first)
            .getOrElse((_) => [])
            .single
            .id,
        b.id,
      );
      expect(
        (await repository
                .watchCustomers(filter: CustomerFilter.settled, query: '٠١٠')
                .first)
            .getOrElse((_) => [])
            .single
            .id,
        a.id,
      );
      expect(
        (await repository.watchCustomerDetails(b.id).first)
            .getOrElse((_) => null)
            ?.balancePiasters,
        200,
      );
      expect(
        await repository.updateCustomer(id: b.id, name: 'Changed'),
        const Right<AppFailure, bool>(true),
      );
      expect(
        await repository.softDeleteCustomer(b.id),
        const Right<AppFailure, bool>(true),
      );
      expect(
        await repository.watchCustomerDetails(b.id).first,
        const Right<AppFailure, CustomerEntity?>(null),
      );
      final created = await repository.createCustomer(name: 'New');
      expect(
        created.getOrElse((_) => throw StateError('failed')).balancePiasters,
        0,
      );
      expect(
        await repository.pickContact(),
        const Right<AppFailure, dynamic>(null),
      );
    },
  );

  test('maps database and picker failures to safe failures', () async {
    expect(
      await repository.createCustomer(name: ' '),
      const Left<AppFailure, CustomerEntity>(
        AppFailure(AppErrorCode.validation),
      ),
    );
    final broken = CustomerRepositoryImpl(
      db.customerDao,
      ContactPickerService(
        pickContact: () async => throw PlatformException(code: 'private'),
      ),
      ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
    );
    expect((await broken.pickContact()).isLeft(), isTrue);
    expect(
      (await broken.pickContact()).swap().getOrElse(
        (_) => throw StateError('failed'),
      ),
      const AppFailure(AppErrorCode.contactPicker),
    );
  });
}
