import 'dart:async';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/soft_delete_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customer_details_usecase.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _Repository implements CustomerRepository {
  final controller = StreamController<Either<AppFailure, CustomerEntity?>>();
  Either<AppFailure, bool> deleteResult = const Right(true);

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) =>
      controller.stream;

  @override
  Future<Either<AppFailure, bool>> softDeleteCustomer(String id) async =>
      deleteResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'observes details, surfaces deletion errors, and closes subscription',
    () async {
      final repository = _Repository();
      final cubit = CustomerDetailsCubit(
        WatchCustomerDetailsUseCase(repository),
        SoftDeleteCustomerUseCase(repository),
      );
      final now = DateTime.utc(2026);
      final customer = CustomerEntity(
        id: 'id',
        name: 'Customer',
        phone: null,
        notes: null,
        balancePiasters: 100,
        createdAt: now,
        updatedAt: now,
      );
      await cubit.load('id');
      repository.controller.add(Right(customer));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.customer, customer);
      repository.deleteResult = const Left(AppFailure(AppErrorCode.database));
      await cubit.delete();
      expect(cubit.state.failure, const AppFailure(AppErrorCode.database));
      repository.deleteResult = const Right(true);
      await cubit.delete();
      expect(cubit.state.deleted, isTrue);
      await cubit.close();
      expect(repository.controller.hasListener, isFalse);
      await repository.controller.close();
    },
  );
}
