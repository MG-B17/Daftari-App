import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../mappers/transaction_mapper.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl(this._dao, this._errors);

  final TransactionDao _dao;
  final ErrorHandler _errors;

  Future<Either<AppFailure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await _errors.handle(error));
    }
  }

  @override
  Stream<Either<AppFailure, List<TransactionEntity>>> watchCustomerTransactions(
    String customerId,
  ) {
    try {
      return _dao
          .watchCustomerTransactions(customerId)
          .transform(
            StreamTransformer<
              List<TransactionRecord>,
              Future<Either<AppFailure, List<TransactionEntity>>>
            >.fromHandlers(
              handleData: (rows, sink) {
                try {
                  sink.add(
                    Future.value(
                      Right(rows.map(TransactionMapper.toEntity).toList()),
                    ),
                  );
                } catch (error) {
                  sink.add(
                    _errors.handle(error).then((failure) => Left(failure)),
                  );
                }
              },
              handleError: (Object error, StackTrace stack, sink) {
                sink.add(
                  _errors.handle(error).then((failure) => Left(failure)),
                );
              },
            ),
          )
          .asyncMap((result) => result);
    } catch (error) {
      return Stream.fromFuture(
        _errors.handle(error).then((failure) => Left(failure)),
      );
    }
  }

  @override
  Future<Either<AppFailure, TransactionEntity?>> getTransactionById(
    String id,
  ) => _run(() async {
    final record = await _dao.getTransactionById(id);
    return record == null ? null : TransactionMapper.toEntity(record);
  });

  @override
  Future<Either<AppFailure, TransactionEntity>> createTransaction({
    required String customerId,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) => _run(() async {
    if (Validators.positivePiasters(amountPiasters) != null) {
      throw const ValidationException();
    }
    final record = await _dao.createTransaction(
      customerId: customerId,
      type: TransactionMapper.toDatabaseType(type),
      amountPiasters: amountPiasters,
      transactionDate: transactionDate,
      note: note,
    );
    return TransactionMapper.toEntity(record);
  });

  @override
  Future<Either<AppFailure, TransactionEntity>> editTransaction({
    required String id,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) => _run(() async {
    if (Validators.positivePiasters(amountPiasters) != null) {
      throw const ValidationException();
    }
    final record = await _dao.editTransaction(
      id: id,
      type: TransactionMapper.toDatabaseType(type),
      amountPiasters: amountPiasters,
      transactionDate: transactionDate,
      note: note,
    );
    return TransactionMapper.toEntity(record);
  });

  @override
  Future<Either<AppFailure, bool>> softDeleteTransaction(String id) =>
      _run(() => _dao.softDeleteTransaction(id));
}
