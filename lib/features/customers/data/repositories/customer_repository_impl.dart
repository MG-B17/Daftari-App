import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/services/contact_picker_service.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/picked_contact.dart';
import '../../domain/repositories/customer_repository.dart';
import '../mappers/customer_mapper.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl(this._dao, this._picker, this._errors);
  final CustomerDao _dao;
  final ContactPickerService _picker;
  final ErrorHandler _errors;

  Stream<Either<AppFailure, T>> _watch<T>(Stream<T> Function() source) async* {
    try {
      await for (final value in source()) {
        yield Right(value);
      }
    } catch (error) {
      yield Left(await _errors.handle(error));
    }
  }

  Future<Either<AppFailure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await _errors.handle(error));
    }
  }

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) => _watch(
    () => _dao.watchCustomersWithBalances().map((rows) {
      final term = query.trim().toLowerCase().toWesternDigits;
      final result = rows
          .map(
            (row) => CustomerMapper.toEntity(row.customer, row.balancePiasters),
          )
          .where((customer) {
            final matches =
                customer.name.toLowerCase().toWesternDigits.contains(term) ||
                (customer.phone?.toWesternDigits.contains(term) ?? false);
            return matches &&
                switch (filter) {
                  CustomerFilter.all => true,
                  CustomerFilter.owes => customer.balancePiasters > 0,
                  CustomerFilter.settled => customer.balancePiasters == 0,
                };
          })
          .toList();
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
    }),
  );

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) =>
      _watch(
        () => _dao
            .watchCustomersWithBalances(id: id)
            .map(
              (rows) => rows.isEmpty
                  ? null
                  : CustomerMapper.toEntity(
                      rows.first.customer,
                      rows.first.balancePiasters,
                    ),
            ),
      );

  @override
  Future<Either<AppFailure, CustomerEntity>> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) => _run(
    () async => CustomerMapper.toEntity(
      await _dao.createCustomer(name: name, phone: phone, notes: notes),
      0,
    ),
  );

  @override
  Future<Either<AppFailure, bool>> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) => _run(
    () => _dao.updateCustomer(id: id, name: name, phone: phone, notes: notes),
  );

  @override
  Future<Either<AppFailure, bool>> softDeleteCustomer(String id) =>
      _run(() => _dao.softDeleteCustomer(id));

  @override
  Future<Either<AppFailure, PickedContact?>> pickContact() =>
      _run(_picker.pickContact);
}
