import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/picked_contact.dart';
import '../../domain/usecases/create_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import '../../domain/usecases/watch_customer_details_usecase.dart';
import '../../domain/usecases/pick_contact_usecase.dart';

enum CustomerFormSubmissionStatus { idle, pending, succeeded, failed }

class CustomerFormState extends Equatable {
  const CustomerFormState({
    this.loading = false,
    this.customer,
    this.failure,
    this.submissionStatus = CustomerFormSubmissionStatus.idle,
    this.submissionId = 0,
    this.submissionFailure,
  });

  final bool loading;
  final CustomerEntity? customer;
  final AppFailure? failure;
  final CustomerFormSubmissionStatus submissionStatus;
  final int submissionId;
  final AppFailure? submissionFailure;

  bool get saving => submissionStatus == CustomerFormSubmissionStatus.pending;
  bool get saved => submissionStatus == CustomerFormSubmissionStatus.succeeded;

  @override
  List<Object?> get props => [
    loading,
    customer,
    failure,
    submissionStatus,
    submissionId,
    submissionFailure,
  ];
}

class CustomerFormCubit extends Cubit<CustomerFormState> {
  CustomerFormCubit(this._create, this._update, this._watch, this._pick)
    : super(const CustomerFormState());
  final CreateCustomerUseCase _create;
  final UpdateCustomerUseCase _update;
  final WatchCustomerDetailsUseCase _watch;
  final PickContactUseCase _pick;
  StreamSubscription<Either<AppFailure, CustomerEntity?>>? _subscription;
  int _generation = 0;
  int _submissionId = 0;
  String? _id;

  Future<void> load(String id) async {
    final generation = ++_generation;
    _id = id;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(CustomerFormState(loading: true, submissionId: _submissionId));
    _subscription = _watch(id).listen(
      (result) {
        if (isClosed ||
            generation != _generation ||
            state.saved ||
            state.saving) {
          return;
        }
        result.fold(
          (failure) => emit(
            CustomerFormState(
              failure: failure,
              customer: state.customer,
              submissionId: _submissionId,
            ),
          ),
          (customer) => emit(
            CustomerFormState(customer: customer, submissionId: _submissionId),
          ),
        );
      },
      onError: (Object error) {
        if (!isClosed &&
            generation == _generation &&
            !state.saved &&
            !state.saving) {
          emit(
            CustomerFormState(
              customer: state.customer,
              failure: const AppFailure(AppErrorCode.unexpected),
              submissionId: _submissionId,
            ),
          );
        }
      },
    );
  }

  Future<Either<AppFailure, PickedContact?>> pickContact() => _pick();

  Future<void> save({
    required String name,
    String? phone,
    String? notes,
  }) async {
    if (state.saving ||
        state.saved ||
        (_id != null && state.customer == null)) {
      return;
    }
    final generation = _generation;
    emit(
      CustomerFormState(
        customer: state.customer,
        submissionStatus: CustomerFormSubmissionStatus.pending,
        submissionId: _submissionId,
      ),
    );
    final id = _id;
    if (id == null) {
      final result = await _create(name: name, phone: phone, notes: notes);
      if (isClosed || generation != _generation) return;
      _submissionId++;
      result.fold(
        (failure) => emit(
          CustomerFormState(
            customer: state.customer,
            submissionStatus: CustomerFormSubmissionStatus.failed,
            submissionId: _submissionId,
            submissionFailure: failure,
          ),
        ),
        (_) => emit(
          CustomerFormState(
            customer: state.customer,
            submissionStatus: CustomerFormSubmissionStatus.succeeded,
            submissionId: _submissionId,
          ),
        ),
      );
    } else {
      final result = await _update(
        id: id,
        name: name,
        phone: phone,
        notes: notes,
      );
      if (isClosed || generation != _generation) return;
      _submissionId++;
      result.fold(
        (failure) => emit(
          CustomerFormState(
            customer: state.customer,
            submissionStatus: CustomerFormSubmissionStatus.failed,
            submissionId: _submissionId,
            submissionFailure: failure,
          ),
        ),
        (updated) => emit(
          CustomerFormState(
            customer: state.customer,
            submissionStatus: updated
                ? CustomerFormSubmissionStatus.succeeded
                : CustomerFormSubmissionStatus.failed,
            submissionId: _submissionId,
            submissionFailure: updated
                ? null
                : const AppFailure(AppErrorCode.database),
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
