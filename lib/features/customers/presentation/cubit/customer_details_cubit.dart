import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/usecases/soft_delete_customer_usecase.dart';
import '../../domain/usecases/watch_customer_details_usecase.dart';

enum CustomerDeleteStatus { idle, pending, succeeded, failed }

class CustomerDetailsState extends Equatable {
  const CustomerDetailsState({
    this.loading = true,
    this.customer,
    this.failure,
    this.deleteStatus = CustomerDeleteStatus.idle,
    this.deleteSubmissionId = 0,
    this.deleteFailure,
  });

  final bool loading;
  final CustomerEntity? customer;
  final AppFailure? failure;
  final CustomerDeleteStatus deleteStatus;
  final int deleteSubmissionId;
  final AppFailure? deleteFailure;

  bool get deleting => deleteStatus == CustomerDeleteStatus.pending;
  bool get deleted => deleteStatus == CustomerDeleteStatus.succeeded;

  @override
  List<Object?> get props => [
    loading,
    customer,
    failure,
    deleteStatus,
    deleteSubmissionId,
    deleteFailure,
  ];
}

class CustomerDetailsCubit extends Cubit<CustomerDetailsState> {
  CustomerDetailsCubit(this._watch, this._delete)
    : super(const CustomerDetailsState());

  final WatchCustomerDetailsUseCase _watch;
  final SoftDeleteCustomerUseCase _delete;
  StreamSubscription<Either<AppFailure, CustomerEntity?>>? _subscription;
  String? _id;
  int _generation = 0;
  int _deleteSubmissionId = 0;

  Future<void> load(String id) async {
    final generation = ++_generation;
    _id = id;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(CustomerDetailsState(deleteSubmissionId: _deleteSubmissionId));
    _subscription = _watch(id).listen(
      (result) {
        if (isClosed ||
            generation != _generation ||
            state.deleted ||
            state.deleting) {
          return;
        }
        result.fold(
          (failure) => emit(
            CustomerDetailsState(
              loading: false,
              customer: state.customer,
              failure: failure,
              deleteSubmissionId: _deleteSubmissionId,
            ),
          ),
          (customer) => emit(
            CustomerDetailsState(
              loading: false,
              customer: customer,
              deleteSubmissionId: _deleteSubmissionId,
            ),
          ),
        );
      },
      onError: (Object error) {
        if (!isClosed &&
            generation == _generation &&
            !state.deleted &&
            !state.deleting) {
          emit(
            CustomerDetailsState(
              loading: false,
              customer: state.customer,
              failure: const AppFailure(AppErrorCode.unexpected),
              deleteSubmissionId: _deleteSubmissionId,
            ),
          );
        }
      },
    );
  }

  Future<void> delete() async {
    final id = _id;
    if (id == null ||
        state.customer == null ||
        state.deleting ||
        state.deleted) {
      return;
    }
    final generation = _generation;
    emit(
      CustomerDetailsState(
        loading: false,
        customer: state.customer,
        deleteStatus: CustomerDeleteStatus.pending,
        deleteSubmissionId: _deleteSubmissionId,
      ),
    );
    final result = await _delete(id);
    if (isClosed || generation != _generation) return;
    _deleteSubmissionId++;
    result.fold(
      (failure) => emit(
        CustomerDetailsState(
          loading: false,
          customer: state.customer,
          deleteStatus: CustomerDeleteStatus.failed,
          deleteSubmissionId: _deleteSubmissionId,
          deleteFailure: failure,
        ),
      ),
      (deleted) => emit(
        CustomerDetailsState(
          loading: false,
          customer: state.customer,
          deleteStatus: deleted
              ? CustomerDeleteStatus.succeeded
              : CustomerDeleteStatus.failed,
          deleteSubmissionId: _deleteSubmissionId,
          deleteFailure: deleted
              ? null
              : const AppFailure(AppErrorCode.database),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
