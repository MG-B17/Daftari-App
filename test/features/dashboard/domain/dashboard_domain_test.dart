import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/entities/debtor_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/entities/recent_activity_entity.dart';
import 'package:daftariapp/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:daftariapp/features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

final now = DateTime.utc(2026, 11, 18, 9, 30);

const debtor = DebtorSummaryEntity(
  id: 'c1',
  name: 'Name',
  phone: null,
  balancePiasters: 320000,
);

final activity = RecentActivityEntity(
  id: 't1',
  customerId: 'c1',
  customerName: 'Name',
  type: TransactionType.credit,
  amountPiasters: 45000,
  transactionDate: now,
  note: 'note',
);

final summary = DashboardSummaryEntity(
  totalOwedPiasters: 1245000,
  debtorCount: 18,
  todayCollectionsPiasters: 150000,
  topDebtors: const [debtor],
  recentActivity: [activity],
);

const failure = AppFailure(AppErrorCode.database);

class FakeDashboardRepository implements DashboardRepository {
  int watches = 0;
  List<Either<AppFailure, DashboardSummaryEntity>> summaries = [Right(summary)];

  @override
  Stream<Either<AppFailure, DashboardSummaryEntity>> watchDashboardSummary() {
    watches++;
    return Stream.fromIterable(summaries);
  }
}

void main() {
  late FakeDashboardRepository repository;
  setUp(() => repository = FakeDashboardRepository());

  test('summary equality compares totals, debtors and activity', () {
    expect(
      summary,
      DashboardSummaryEntity(
        totalOwedPiasters: 1245000,
        debtorCount: 18,
        todayCollectionsPiasters: 150000,
        topDebtors: const [debtor],
        recentActivity: [activity],
      ),
    );
    expect(
      summary,
      isNot(
        DashboardSummaryEntity(
          totalOwedPiasters: 0,
          debtorCount: 18,
          todayCollectionsPiasters: 150000,
          topDebtors: const [debtor],
          recentActivity: [activity],
        ),
      ),
    );
    expect(
      summary,
      isNot(
        DashboardSummaryEntity(
          totalOwedPiasters: 1245000,
          debtorCount: 18,
          todayCollectionsPiasters: 150000,
          topDebtors: const [],
          recentActivity: [activity],
        ),
      ),
    );
  });

  test('empty summary has zero totals and no lists', () {
    const empty = DashboardSummaryEntity.empty();
    expect(empty.totalOwedPiasters, 0);
    expect(empty.debtorCount, 0);
    expect(empty.todayCollectionsPiasters, 0);
    expect(empty.topDebtors, isEmpty);
    expect(empty.recentActivity, isEmpty);
    expect(empty.hasDebtors, isFalse);
    expect(empty.hasRecentActivity, isFalse);
    expect(summary.hasDebtors, isTrue);
    expect(summary.hasRecentActivity, isTrue);
  });

  test('debtor and activity equality include every field', () {
    expect(
      debtor,
      const DebtorSummaryEntity(
        id: 'c1',
        name: 'Name',
        phone: null,
        balancePiasters: 320000,
      ),
    );
    expect(
      debtor,
      isNot(
        const DebtorSummaryEntity(
          id: 'c1',
          name: 'Name',
          phone: '01012345678',
          balancePiasters: 320000,
        ),
      ),
    );
    expect(
      activity,
      RecentActivityEntity(
        id: 't1',
        customerId: 'c1',
        customerName: 'Name',
        type: TransactionType.credit,
        amountPiasters: 45000,
        transactionDate: now,
        note: 'note',
      ),
    );
    expect(
      activity,
      isNot(
        RecentActivityEntity(
          id: 't1',
          customerId: 'c1',
          customerName: 'Name',
          type: TransactionType.payment,
          amountPiasters: 45000,
          transactionDate: now,
          note: 'note',
        ),
      ),
    );
    expect(activity.isCredit, isTrue);
    expect(
      RecentActivityEntity(
        id: 't2',
        customerId: 'c1',
        customerName: 'Name',
        type: TransactionType.payment,
        amountPiasters: 45000,
        transactionDate: now,
      ).isCredit,
      isFalse,
    );
  });

  test('watch forwards successive values and failures unchanged', () async {
    repository.summaries = [
      Right(summary),
      const Left(failure),
      const Right(DashboardSummaryEntity.empty()),
    ];
    expect(
      await WatchDashboardSummaryUseCase(repository)().toList(),
      repository.summaries,
    );
    expect(repository.watches, 1);
  });
}
