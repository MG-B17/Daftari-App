import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../mappers/search_customer_mapper.dart';

class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl(this._dao, this._errors);

  final CustomerDao _dao;
  final ErrorHandler _errors;

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchSearchableCustomers() {
    try {
      return _dao
          .watchCustomersWithBalances()
          .map((rows) {
            final customers = rows.map(SearchCustomerMapper.toEntity).toList();
            customers.sort((a, b) {
              final byName = a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
              return byName != 0 ? byName : a.id.compareTo(b.id);
            });
            return customers;
          })
          .transform(
            StreamTransformer<
              List<CustomerEntity>,
              Future<Either<AppFailure, List<CustomerEntity>>>
            >.fromHandlers(
              handleData: (value, sink) => sink.add(Future.value(Right(value))),
              handleError: (Object error, StackTrace stack, sink) => sink.add(
                _errors.handle(error).then((failure) => Left(failure)),
              ),
            ),
          )
          .asyncMap((result) => result);
    } catch (error) {
      return Stream.fromFuture(
        _errors.handle(error).then((failure) => Left(failure)),
      );
    }
  }
}
