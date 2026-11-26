import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/soft_delete_transaction_usecase.dart';
import '../../domain/usecases/watch_customer_transactions_usecase.dart';

enum TransactionDeleteStatus { idle, pending, succeeded, failed }

class CustomerTransactionsState extends Equatable {
  const CustomerTransactionsState({
    this.loading = true,
    this.entries = const [],
    this.runningBalances = const {},
    this.failure,
    this.deleteStatus = TransactionDeleteStatus.idle,
    this.deleteSubmissionId = 0,
    this.deleteFailure,
    this.deletingTransactionId,
  });

  final bool loading;
  final List<TransactionEntity> entries;
  final Map<String, BigInt> runningBalances;
  final AppFailure? failure;
  final TransactionDeleteStatus deleteStatus;
  final int deleteSubmissionId;
  final AppFailure? deleteFailure;
  final String? deletingTransactionId;

  bool get deleting => deleteStatus == TransactionDeleteStatus.pending;
  bool get deleted => deleteStatus == TransactionDeleteStatus.succeeded;

  @override
  List<Object?> get props => [
    loading,
    entries,
    runningBalances,
    failure,
    deleteStatus,
    deleteSubmissionId,
    deleteFailure,
    deletingTransactionId,
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
  int _deleteSubmissionId = 0;

  Future<void> load(String customerId) async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(CustomerTransactionsState(deleteSubmissionId: _deleteSubmissionId));
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
              deleteStatus: state.deleteStatus,
              deleteSubmissionId: _deleteSubmissionId,
              deleteFailure: state.deleteFailure,
              deletingTransactionId: state.deletingTransactionId,
            ),
          ),
          (entries) => emit(
            CustomerTransactionsState(
              loading: false,
              entries: entries,
              runningBalances: _calculateRunningBalances(entries),
              deleteStatus: state.deleteStatus,
              deleteSubmissionId: _deleteSubmissionId,
              deleteFailure: state.deleteFailure,
              deletingTransactionId: state.deletingTransactionId,
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
              deleteStatus: state.deleteStatus,
              deleteSubmissionId: _deleteSubmissionId,
              deleteFailure: state.deleteFailure,
              deletingTransactionId: state.deletingTransactionId,
            ),
          );
        }
      },
    );
  }

  Future<void> delete(String id) async {
    if (state.deleting) return;
    final generation = _generation;
    emit(
      CustomerTransactionsState(
        loading: false,
        entries: state.entries,
        runningBalances: state.runningBalances,
        failure: state.failure,
        deleteStatus: TransactionDeleteStatus.pending,
        deleteSubmissionId: _deleteSubmissionId,
        deletingTransactionId: id,
      ),
    );
    final result = await _delete(id);
    if (isClosed || generation != _generation) return;
    _deleteSubmissionId++;
    result.fold(
      (failure) => emit(
        CustomerTransactionsState(
          loading: false,
          entries: state.entries,
          runningBalances: state.runningBalances,
          failure: state.failure,
          deleteStatus: TransactionDeleteStatus.failed,
          deleteSubmissionId: _deleteSubmissionId,
          deleteFailure: failure,
        ),
      ),
      (deleted) => emit(
        CustomerTransactionsState(
          loading: false,
          entries: state.entries,
          runningBalances: state.runningBalances,
          failure: state.failure,
          deleteStatus: deleted
              ? TransactionDeleteStatus.succeeded
              : TransactionDeleteStatus.failed,
          deleteSubmissionId: _deleteSubmissionId,
          deleteFailure: deleted
              ? null
              : const AppFailure(AppErrorCode.validation),
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
