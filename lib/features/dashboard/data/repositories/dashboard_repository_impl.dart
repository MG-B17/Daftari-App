import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/date_service.dart';
import '../../../transactions/data/mappers/transaction_mapper.dart';
import '../../domain/entities/dashboard_summary_entity.dart';
import '../../domain/entities/debtor_summary_entity.dart';
import '../../domain/entities/recent_activity_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(
    this._customers,
    this._transactions,
    this._errors,
    this._dates,
  );

  final CustomerDao _customers;
  final TransactionDao _transactions;
  final ErrorHandler _errors;
  final DateService _dates;

  @override
  Stream<Either<AppFailure, DashboardSummaryEntity>> watchDashboardSummary() {
    late StreamController<DashboardSummaryEntity> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    List<CustomerWithBalance>? balances;
    List<TransactionWithCustomer>? activity;
    int? collections;
    var completed = 0;

    void emit() {
      final currentBalances = balances;
      final currentActivity = activity;
      final currentCollections = collections;
      if (currentBalances == null ||
          currentActivity == null ||
          currentCollections == null) {
        return;
      }
      final debtors =
          currentBalances.where((row) => row.balancePiasters > 0).toList()
            ..sort((a, b) {
              final balanceOrder = b.balancePiasters.compareTo(
                a.balancePiasters,
              );
              return balanceOrder != 0
                  ? balanceOrder
                  : a.customer.id.compareTo(b.customer.id);
            });
      controller.add(
        DashboardSummaryEntity(
          totalOwedPiasters: debtors.fold(
            0,
            (total, row) => total + row.balancePiasters,
          ),
          debtorCount: debtors.length,
          todayCollectionsPiasters: currentCollections,
          topDebtors: debtors
              .take(3)
              .map(
                (row) => DebtorSummaryEntity(
                  id: row.customer.id,
                  name: row.customer.name,
                  phone: row.customer.phone,
                  balancePiasters: row.balancePiasters,
                ),
              )
              .toList(),
          recentActivity: currentActivity.map((row) {
            final entry = TransactionMapper.toEntity(row.transaction);
            return RecentActivityEntity(
              id: entry.id,
              customerId: entry.customerId,
              customerName: row.customer.name,
              type: entry.type,
              amountPiasters: entry.amountPiasters,
              transactionDate: entry.transactionDate,
              note: entry.note,
            );
          }).toList(),
        ),
      );
    }

    void listen<T>(
      Stream<T> source,
      void Function(T) update,
      void Function() invalidate,
    ) {
      subscriptions.add(
        source.listen(
          (value) {
            try {
              update(value);
              emit();
            } catch (error, stack) {
              invalidate();
              controller.addError(error, stack);
            }
          },
          onError: (Object error, StackTrace stack) {
            invalidate();
            controller.addError(error, stack);
          },
          onDone: () {
            if (++completed == 3) controller.close();
          },
        ),
      );
    }

    controller = StreamController<DashboardSummaryEntity>(
      onListen: () {
        try {
          final now = _dates.now().toLocal();
          final start = DateTime(now.year, now.month, now.day);
          final end = DateTime(now.year, now.month, now.day + 1);
          listen(
            _customers.watchCustomersWithBalances(),
            (value) => balances = value,
            () => balances = null,
          );
          listen(
            _transactions.watchRecentTransactionsWithCustomer(limit: 5),
            (value) => activity = value,
            () => activity = null,
          );
          listen(
            _transactions.watchTodayPaymentsPiasters(start, end),
            (value) => collections = value,
            () => collections = null,
          );
        } catch (error, stack) {
          controller.addError(error, stack);
          controller.close();
        }
      },
      onPause: () {
        for (final subscription in subscriptions) {
          subscription.pause();
        }
      },
      onResume: () {
        for (final subscription in subscriptions) {
          subscription.resume();
        }
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return controller.stream
        .transform(
          StreamTransformer<
            DashboardSummaryEntity,
            Future<Either<AppFailure, DashboardSummaryEntity>>
          >.fromHandlers(
            handleData: (value, sink) => sink.add(Future.value(Right(value))),
            handleError: (Object error, StackTrace stack, sink) => sink.add(
              _errors.handle(error).then((failure) => Left(failure)),
            ),
          ),
        )
        .asyncMap((result) => result);
  }
}
