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
  Completer<Either<AppFailure, bool>>? pendingDelete;
  int deleteCalls = 0;

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) =>
      controller.stream;

  @override
  Future<Either<AppFailure, bool>> softDeleteCustomer(String id) async {
    deleteCalls++;
    if (pendingDelete != null) return pendingDelete!.future;
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('observes details, surfaces deletion outcomes once per submission, and closes subscription', () async {
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
    expect(cubit.state.deleteStatus, CustomerDeleteStatus.failed);
    expect(cubit.state.deleteSubmissionId, 1);
    expect(cubit.state.deleteFailure, const AppFailure(AppErrorCode.database));

    // A repeated identical failure still increments deleteSubmissionId.
    await cubit.delete();
    expect(cubit.state.deleteSubmissionId, 2);
    expect(cubit.state.deleteFailure, const AppFailure(AppErrorCode.database));

    repository.deleteResult = const Right(true);
    await cubit.delete();
    expect(cubit.state.deleted, isTrue);
    expect(cubit.state.deleteSubmissionId, 3);
    expect(cubit.state.deleteFailure, isNull);

    // Further delete calls after success are ignored.
    final callsAfterSuccess = repository.deleteCalls;
    await cubit.delete();
    expect(repository.deleteCalls, callsAfterSuccess);

    await cubit.close();
    expect(repository.controller.hasListener, isFalse);
    await repository.controller.close();
  });

  test('ignores duplicate delete taps and null stream updates while delete is pending', () async {
    final repository = _Repository();
    final pending = Completer<Either<AppFailure, bool>>();
    repository.pendingDelete = pending;
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
      balancePiasters: 0,
      createdAt: now,
      updatedAt: now,
    );
    await cubit.load('id');
    repository.controller.add(Right(customer));
    await Future<void>.delayed(Duration.zero);

    final first = cubit.delete();
    final second = cubit.delete();
    expect(cubit.state.deleting, isTrue);
    expect(repository.deleteCalls, 1);

    // Stream reporting null mid-delete must not clear the visible customer.
    repository.controller.add(const Right(null));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.customer, customer);
    expect(cubit.state.deleting, isTrue);

    pending.complete(const Right(true));
    await Future.wait([first, second]);
    expect(cubit.state.deleted, isTrue);
    expect(cubit.state.customer, customer);
    expect(cubit.state.deleteSubmissionId, 1);

    await cubit.close();
    await repository.controller.close();
  });

  test('closing cubit during pending delete completes safely', () async {
    final repository = _Repository();
    final pending = Completer<Either<AppFailure, bool>>();
    repository.pendingDelete = pending;
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
      balancePiasters: 0,
      createdAt: now,
      updatedAt: now,
    );
    await cubit.load('id');
    repository.controller.add(Right(customer));
    await Future<void>.delayed(Duration.zero);

    final deleteFuture = cubit.delete();
    await cubit.close();
    pending.complete(const Right(true));
    await deleteFuture;
    await repository.controller.close();
  });
}
