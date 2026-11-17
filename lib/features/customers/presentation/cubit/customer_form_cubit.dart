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

class CustomerFormState extends Equatable {
  const CustomerFormState({
    this.loading = false,
    this.customer,
    this.failure,
    this.saving = false,
    this.saved = false,
  });
  final bool loading;
  final CustomerEntity? customer;
  final AppFailure? failure;
  final bool saving;
  final bool saved;

  @override
  List<Object?> get props => [loading, customer, failure, saving, saved];
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
  String? _id;

  Future<void> load(String id) async {
    final generation = ++_generation;
    _id = id;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(const CustomerFormState(loading: true));
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
            CustomerFormState(failure: failure, customer: state.customer),
          ),
          (customer) => emit(CustomerFormState(customer: customer)),
        );
      },
      onError: (Object error) {
        if (!isClosed && generation == _generation) {
          emit(
            const CustomerFormState(
              failure: AppFailure(AppErrorCode.unexpected),
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
    if (state.saving) return;
    final generation = _generation;
    emit(CustomerFormState(customer: state.customer, saving: true));
    final id = _id;
    if (id == null) {
      final result = await _create(name: name, phone: phone, notes: notes);
      if (isClosed || generation != _generation) return;
      result.fold(
        (failure) =>
            emit(CustomerFormState(customer: state.customer, failure: failure)),
        (_) => emit(CustomerFormState(customer: state.customer, saved: true)),
      );
    } else {
      final result = await _update(
        id: id,
        name: name,
        phone: phone,
        notes: notes,
      );
      if (isClosed || generation != _generation) return;
      result.fold(
        (failure) =>
            emit(CustomerFormState(customer: state.customer, failure: failure)),
        (updated) => emit(
          CustomerFormState(
            customer: state.customer,
            saved: updated,
            failure: updated ? null : const AppFailure(AppErrorCode.database),
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
