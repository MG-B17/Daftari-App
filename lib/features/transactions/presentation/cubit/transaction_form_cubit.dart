import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

enum TransactionFormSubmissionStatus { idle, pending, succeeded, failed }

class TransactionFormState extends Equatable {
  const TransactionFormState({
    this.loading = false,
    this.customers = const [],
    this.transaction,
    this.failure,
    this.submissionStatus = TransactionFormSubmissionStatus.idle,
    this.submissionId = 0,
    this.submissionFailure,
    this.savedType,
  });

  final bool loading;
  final List<CustomerEntity> customers;
  final TransactionEntity? transaction;
  final AppFailure? failure;
  final TransactionFormSubmissionStatus submissionStatus;
  final int submissionId;
  final AppFailure? submissionFailure;
  final TransactionType? savedType;

  bool get saving =>
      submissionStatus == TransactionFormSubmissionStatus.pending;
  bool get saved =>
      submissionStatus == TransactionFormSubmissionStatus.succeeded;

  @override
  List<Object?> get props => [
    loading,
    customers,
    transaction,
    failure,
    submissionStatus,
    submissionId,
    submissionFailure,
    savedType,
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
  int _submissionId = 0;
  List<CustomerEntity>? _bufferedCustomers;
  AppFailure? _bufferedCustomersFailure;

  Future<void> load(String? id) async {
    final generation = ++_generation;
    _bufferedCustomers = null;
    _bufferedCustomersFailure = null;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    _id = id;
    if (id != null) {
      emit(
        TransactionFormState(
          loading: true,
          customers: state.customers,
          submissionId: _submissionId,
        ),
      );
    }
    _subscription = _watchCustomers().listen(
      (result) {
        if (isClosed || generation != _generation || state.saved) {
          return;
        }
        if (state.saving) {
          result.fold((failure) => _bufferedCustomersFailure = failure, (
            customers,
          ) {
            _bufferedCustomers = customers;
            _bufferedCustomersFailure = null;
          });
          return;
        }
        result.fold(
          (failure) => emit(
            TransactionFormState(
              loading: state.loading,
              transaction: state.transaction,
              customers: state.customers,
              failure: failure,
              submissionStatus: state.submissionStatus,
              submissionId: _submissionId,
              submissionFailure: state.submissionFailure,
              savedType: state.savedType,
            ),
          ),
          (customers) => emit(
            TransactionFormState(
              loading: state.loading,
              transaction: state.transaction,
              customers: customers,
              failure: state.failure,
              submissionStatus: state.submissionStatus,
              submissionId: _submissionId,
              submissionFailure: state.submissionFailure,
              savedType: state.savedType,
            ),
          ),
        );
      },
      onError: (Object _) {
        if (isClosed || generation != _generation || state.saved) {
          return;
        }
        if (state.saving) {
          _bufferedCustomersFailure = const AppFailure(AppErrorCode.unexpected);
          return;
        }
        emit(
          TransactionFormState(
            loading: false,
            failure: const AppFailure(AppErrorCode.unexpected),
            transaction: state.transaction,
            customers: state.customers,
            submissionStatus: state.submissionStatus,
            submissionId: _submissionId,
            submissionFailure: state.submissionFailure,
            savedType: state.savedType,
          ),
        );
      },
    );
    if (id == null) {
      emit(
        TransactionFormState(
          customers: state.customers,
          submissionId: _submissionId,
        ),
      );
      return;
    }
    final result = await _get(id);
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(
        TransactionFormState(
          failure: failure,
          customers: state.customers,
          submissionId: _submissionId,
        ),
      ),
      (transaction) => emit(
        TransactionFormState(
          transaction: transaction,
          customers: state.customers,
          failure: transaction == null
              ? const AppFailure(AppErrorCode.validation)
              : null,
          submissionId: _submissionId,
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
      _submissionId++;
      emit(
        TransactionFormState(
          customers: state.customers,
          transaction: state.transaction,
          submissionStatus: TransactionFormSubmissionStatus.failed,
          submissionId: _submissionId,
          submissionFailure: const AppFailure(AppErrorCode.validation),
        ),
      );
      return;
    }
    _bufferedCustomers = null;
    _bufferedCustomersFailure = null;
    emit(
      TransactionFormState(
        customers: state.customers,
        transaction: state.transaction,
        submissionStatus: TransactionFormSubmissionStatus.pending,
        submissionId: _submissionId,
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
    final bufferedCustomers = _bufferedCustomers;
    final bufferedFailure = _bufferedCustomersFailure;
    _bufferedCustomers = null;
    _bufferedCustomersFailure = null;
    _submissionId++;
    result.fold(
      (failure) => emit(
        TransactionFormState(
          customers: bufferedCustomers ?? state.customers,
          transaction: state.transaction,
          failure: bufferedFailure ?? state.failure,
          submissionStatus: TransactionFormSubmissionStatus.failed,
          submissionId: _submissionId,
          submissionFailure: failure,
        ),
      ),
      (_) => emit(
        TransactionFormState(
          customers: state.customers,
          transaction: state.transaction,
          submissionStatus: TransactionFormSubmissionStatus.succeeded,
          submissionId: _submissionId,
          savedType: type,
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
