import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/soft_delete_transaction_usecase.dart';
import '../../domain/usecases/watch_customer_transactions_usecase.dart';

class CustomerTransactionsState extends Equatable {
  const CustomerTransactionsState({
    this.loading = true,
    this.entries = const [],
    this.runningBalances = const {},
    this.failure,
    this.deleting = false,
  });
  final bool loading;
  final List<TransactionEntity> entries;
  final Map<String, BigInt> runningBalances;
  final AppFailure? failure;
  final bool deleting;
  @override
  List<Object?> get props => [
    loading,
    entries,
    runningBalances,
    failure,
    deleting,
  ];
}

class CustomerTransactionsCubit extends Cubit<CustomerTransactionsState> {
  CustomerTransactionsCubit(this._watch, this._delete)
    : super(const CustomerTransactionsState());
  final WatchCustomerTransactionsUseCase _watch;
  final SoftDeleteTransactionUseCase _delete;
  StreamSubscription<Either<AppFailure, List<TransactionEntity>>>?
  _subscription;
  int _generation = 0;

  Future<void> load(String customerId) async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(const CustomerTransactionsState());
    _subscription = _watch(customerId).listen(
      (result) {
        if (isClosed || generation != _generation) return;
        result.fold(
          (failure) => emit(
            CustomerTransactionsState(
              loading: false,
              failure: failure,
              entries: state.entries,
              runningBalances: state.runningBalances,
              deleting: state.deleting,
            ),
          ),
          (entries) => emit(
            CustomerTransactionsState(
              loading: false,
              entries: entries,
              runningBalances: _calculateRunningBalances(entries),
              deleting: state.deleting,
            ),
          ),
        );
      },
      onError: (Object _) {
        if (!isClosed && generation == _generation) {
          emit(
            CustomerTransactionsState(
              loading: false,
              entries: state.entries,
              runningBalances: state.runningBalances,
              failure: const AppFailure(AppErrorCode.unexpected),
              deleting: state.deleting,
            ),
          );
        }
      },
    );
  }

  Future<void> delete(String id) async {
    if (state.deleting) return;
    emit(
      CustomerTransactionsState(
        loading: false,
        entries: state.entries,
        runningBalances: state.runningBalances,
        deleting: true,
      ),
    );
    final result = await _delete(id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        CustomerTransactionsState(
          loading: false,
          entries: state.entries,
          runningBalances: state.runningBalances,
          failure: failure,
        ),
      ),
      (deleted) => emit(
        CustomerTransactionsState(
          loading: false,
          entries: state.entries,
          runningBalances: state.runningBalances,
          failure: deleted ? null : const AppFailure(AppErrorCode.validation),
        ),
      ),
    );
  }

  static Map<String, BigInt> _calculateRunningBalances(
    List<TransactionEntity> entries,
  ) {
    final balances = <String, BigInt>{};
    var total = BigInt.zero;
    for (final entry in entries.reversed) {
      final amount = BigInt.from(entry.amountPiasters);
      total += entry.type == TransactionType.credit ? amount : -amount;
      balances[entry.id] = total;
    }
    return Map.unmodifiable(balances);
  }

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
