import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/picked_contact.dart';
import '../../domain/usecases/pick_contact_usecase.dart';
import '../../domain/usecases/watch_customers_usecase.dart';

class CustomersListState extends Equatable {
  const CustomersListState({
    this.loading = true,
    this.customers = const [],
    this.filter = CustomerFilter.all,
    this.sort = CustomerSort.nameAsc,
    this.failure,
  });

  final bool loading;
  final List<CustomerEntity> customers;
  final CustomerFilter filter;
  final CustomerSort sort;
  final AppFailure? failure;

  int get owing => customers.where((c) => c.balancePiasters > 0).length;
  int get settled => customers.where((c) => c.balancePiasters == 0).length;
  int get totalDebt => customers.fold(0, (sum, c) => sum + c.balancePiasters);

  List<CustomerEntity> get visible {
    final result = customers.where((customer) {
      return switch (filter) {
        CustomerFilter.all => true,
        CustomerFilter.owes => customer.balancePiasters > 0,
        CustomerFilter.settled => customer.balancePiasters == 0,
      };
    }).toList();
    result.sort((a, b) {
      final comparison = switch (sort) {
        CustomerSort.nameAsc => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        CustomerSort.balanceDesc => b.balancePiasters.compareTo(
          a.balancePiasters,
        ),
        CustomerSort.recent => b.createdAt.compareTo(a.createdAt),
      };
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
    return result;
  }

  CustomersListState copyWith({
    bool? loading,
    List<CustomerEntity>? customers,
    CustomerFilter? filter,
    CustomerSort? sort,
    AppFailure? failure,
  }) => CustomersListState(
    loading: loading ?? this.loading,
    customers: customers ?? this.customers,
    filter: filter ?? this.filter,
    sort: sort ?? this.sort,
    failure: failure,
  );

  @override
  List<Object?> get props => [loading, customers, filter, sort, failure];
}

class CustomersListCubit extends Cubit<CustomersListState> {
  CustomersListCubit(this._watch, this._pick)
    : super(const CustomersListState());
  final WatchCustomersUseCase _watch;
  final PickContactUseCase _pick;
  StreamSubscription<Either<AppFailure, List<CustomerEntity>>>? _subscription;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(state.copyWith(loading: true));
    _subscription = _watch().listen(
      (result) {
        if (isClosed || generation != _generation) return;
        result.fold(
          (failure) => emit(state.copyWith(loading: false, failure: failure)),
          (customers) =>
              emit(state.copyWith(loading: false, customers: customers)),
        );
      },
      onError: (Object error) {
        if (!isClosed && generation == _generation) {
          emit(
            state.copyWith(
              loading: false,
              failure: const AppFailure(AppErrorCode.unexpected),
            ),
          );
        }
      },
    );
  }

  void setFilter(CustomerFilter filter) =>
      emit(state.copyWith(filter: filter, failure: state.failure));
  void setSort(CustomerSort sort) =>
      emit(state.copyWith(sort: sort, failure: state.failure));

  Future<Either<AppFailure, PickedContact?>> pickContact() => _pick();

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
