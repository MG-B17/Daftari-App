import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/amount_input_utils.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/usecases/watch_customers_usecase.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/create_transaction_usecase.dart';
import '../../domain/usecases/edit_transaction_usecase.dart';
import '../../domain/usecases/get_transaction_by_id_usecase.dart';

class TransactionFormState extends Equatable {
  const TransactionFormState({
    this.loading = false,
    this.customers = const [],
    this.transaction,
    this.failure,
    this.saving = false,
    this.saved = false,
  });
  final bool loading;
  final List<CustomerEntity> customers;
  final TransactionEntity? transaction;
  final AppFailure? failure;
  final bool saving;
  final bool saved;
  @override
  List<Object?> get props => [
    loading,
    customers,
    transaction,
    failure,
    saving,
    saved,
  ];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit(
    this._watchCustomers,
    this._get,
    this._create,
    this._edit,
  ) : super(const TransactionFormState(loading: true));
  final WatchCustomersUseCase _watchCustomers;
  final GetTransactionByIdUseCase _get;
  final CreateTransactionUseCase _create;
  final EditTransactionUseCase _edit;
  StreamSubscription<Either<AppFailure, List<CustomerEntity>>>? _subscription;
  String? _id;
  int _generation = 0;

  Future<void> load(String? id) async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    _id = id;
    _subscription = _watchCustomers().listen(
      (result) {
        if (isClosed || generation != _generation) return;
        result.fold(
          (failure) => emit(
            TransactionFormState(
              loading: state.loading,
              transaction: state.transaction,
              customers: state.customers,
              saving: state.saving,
              saved: state.saved,
              failure: failure,
            ),
          ),
          (customers) => emit(
            TransactionFormState(
              loading: state.loading,
              transaction: state.transaction,
              customers: customers,
              saving: state.saving,
              saved: state.saved,
              failure: state.failure,
            ),
          ),
        );
      },
      onError: (Object _) {
        if (!isClosed && generation == _generation) {
          emit(
            TransactionFormState(
              loading: false,
              failure: const AppFailure(AppErrorCode.unexpected),
              transaction: state.transaction,
              customers: state.customers,
              saving: state.saving,
              saved: state.saved,
            ),
          );
        }
      },
    );
    if (id == null) {
      emit(TransactionFormState(customers: state.customers));
      return;
    }
    final result = await _get(id);
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(
        TransactionFormState(failure: failure, customers: state.customers),
      ),
      (transaction) => emit(
        TransactionFormState(
          transaction: transaction,
          customers: state.customers,
          failure: transaction == null
              ? const AppFailure(AppErrorCode.validation)
              : null,
        ),
      ),
    );
  }

  Future<void> save({
    required String? customerId,
    required TransactionType type,
    required String amount,
    required DateTime date,
    String? note,
  }) async {
    if (state.saving || state.saved || state.loading) return;
    final generation = _generation;
    final parsed = AmountInputUtils.tryParseInputToPiasters(amount);
    if ((_id != null &&
            (state.transaction == null ||
                state.transaction!.customerId != customerId)) ||
        customerId == null ||
        !state.customers.any((c) => c.id == customerId) ||
        parsed == null ||
        parsed <= 0) {
      emit(
        TransactionFormState(
          customers: state.customers,
          transaction: state.transaction,
          failure: const AppFailure(AppErrorCode.validation),
        ),
      );
      return;
    }
    emit(
      TransactionFormState(
        customers: state.customers,
        transaction: state.transaction,
        saving: true,
      ),
    );
    final existing = state.transaction;
    final result = existing == null
        ? await _create(
            customerId: customerId,
            type: type,
            amountPiasters: parsed,
            transactionDate: date,
            note: note,
          )
        : await _edit(
            id: existing.id,
            type: type,
            amountPiasters: parsed,
            transactionDate: date,
            note: note,
          );
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(
        TransactionFormState(
          customers: state.customers,
          transaction: state.transaction,
          failure: failure,
        ),
      ),
      (_) => emit(
        TransactionFormState(
          customers: state.customers,
          transaction: state.transaction,
          saved: true,
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
