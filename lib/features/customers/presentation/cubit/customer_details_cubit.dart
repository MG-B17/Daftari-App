import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/usecases/soft_delete_customer_usecase.dart';
import '../../domain/usecases/watch_customer_details_usecase.dart';

class CustomerDetailsState extends Equatable {
  const CustomerDetailsState({
    this.loading = true,
    this.customer,
    this.failure,
    this.deleting = false,
    this.deleted = false,
  });

  final bool loading;
  final CustomerEntity? customer;
  final AppFailure? failure;
  final bool deleting;
  final bool deleted;

  @override
  List<Object?> get props => [loading, customer, failure, deleting, deleted];
}

class CustomerDetailsCubit extends Cubit<CustomerDetailsState> {
  CustomerDetailsCubit(this._watch, this._delete)
    : super(const CustomerDetailsState());

  final WatchCustomerDetailsUseCase _watch;
  final SoftDeleteCustomerUseCase _delete;
  StreamSubscription<Either<AppFailure, CustomerEntity?>>? _subscription;
  String? _id;
  int _generation = 0;

  Future<void> load(String id) async {
    final generation = ++_generation;
    _id = id;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(const CustomerDetailsState());
    _subscription = _watch(id).listen(
      (result) {
        if (isClosed || generation != _generation || state.deleted) return;
        result.fold(
          (failure) => emit(
            CustomerDetailsState(
              loading: false,
              customer: state.customer,
              failure: failure,
              deleting: state.deleting,
            ),
          ),
          (customer) => emit(
            CustomerDetailsState(
              loading: false,
              customer: customer,
              deleting: state.deleting,
            ),
          ),
        );
      },
      onError: (Object error) {
        if (!isClosed && generation == _generation && !state.deleted) {
          emit(
            CustomerDetailsState(
              loading: false,
              customer: state.customer,
              failure: const AppFailure(AppErrorCode.unexpected),
              deleting: state.deleting,
            ),
          );
        }
      },
    );
  }

  Future<void> delete() async {
    final id = _id;
    if (id == null || state.customer == null || state.deleting) return;
    final generation = _generation;
    emit(
      CustomerDetailsState(
        loading: false,
        customer: state.customer,
        deleting: true,
      ),
    );
    final result = await _delete(id);
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(
        CustomerDetailsState(
          loading: false,
          customer: state.customer,
          failure: failure,
        ),
      ),
      (deleted) => emit(
        CustomerDetailsState(
          loading: false,
          customer: state.customer,
          deleted: deleted,
          failure: deleted ? null : const AppFailure(AppErrorCode.database),
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
