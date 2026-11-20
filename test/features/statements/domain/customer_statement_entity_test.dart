import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statement_fixtures.dart';

void main() {
  test('derives exact piaster totals, ignoring customer balance snapshot', () {
    final statement = statementFixture(
      entries: [
        statementTransaction(amount: 101),
        statementTransaction(id: 't2', amount: 202),
        statementTransaction(
          id: 't3',
          type: TransactionType.payment,
          amount: 104,
        ),
      ],
    );
    expect(statement.balancePiasters, 199);
    expect(statement.periodCreditPiasters, 303);
    expect(statement.periodPaymentPiasters, 104);
  });

  test('range filters totals and entries, never the full-ledger balance', () {
    final statement = statementFixture(
      range: StatementDateRange.thisMonth,
      entries: [
        statementTransaction(amount: 10000, date: DateTime(2026, 10)),
        statementTransaction(id: 't2', amount: 101),
        statementTransaction(
          id: 't3',
          type: TransactionType.payment,
          amount: 104,
        ),
      ],
    );
    expect(statement.entries.map((e) => e.id), ['t2', 't3']);
    expect(statement.balancePiasters, 9997);
    expect(statement.periodCreditPiasters, 101);
    expect(statement.periodPaymentPiasters, 104);
    expect(statement.generatedAt, statementNow);
    expect(statement.range, StatementDateRange.thisMonth);
  });

  test('empty period retains prior balance with zero period totals', () {
    final statement = statementFixture(
      range: StatementDateRange.thisMonth,
      entries: [statementTransaction(amount: 123, date: DateTime(2025))],
    );
    expect(statement.entries, isEmpty);
    expect(statement.balancePiasters, 123);
    expect(statement.periodCreditPiasters, 0);
    expect(statement.periodPaymentPiasters, 0);
  });

  test('empty ledger has zero totals and balance', () {
    final statement = statementFixture();
    expect(statement.entries, isEmpty);
    expect(statement.balancePiasters, 0);
    expect(statement.periodCreditPiasters, 0);
    expect(statement.periodPaymentPiasters, 0);
  });

  test('payment-only ledger supports a negative balance', () {
    final statement = statementFixture(
      entries: [
        statementTransaction(type: TransactionType.payment, amount: 101),
      ],
    );
    expect(statement.balancePiasters, -101);
    expect(statement.periodCreditPiasters, 0);
    expect(statement.periodPaymentPiasters, 101);
  });

  test('sorts newest-first with created time and ID tie breakers', () {
    final input = [
      statementTransaction(id: 'old', date: DateTime(2025)),
      statementTransaction(id: 'b'),
      statementTransaction(id: 'early', createdAt: DateTime(2026)),
      statementTransaction(id: 'a'),
    ];
    final statement = statementFixture(entries: input);
    expect(statement.entries.map((e) => e.id), ['a', 'b', 'early', 'old']);
    expect(input.first.id, 'old');
    input.clear();
    expect(statement.entries, hasLength(4));
    expect(() => statement.entries.clear(), throwsUnsupportedError);
  });

  test('rejects a ledger entry belonging to a different customer', () {
    expect(
      () => statementFixture(
        entries: [statementTransaction(customerId: 'another')],
      ),
      throwsArgumentError,
    );
  });

  test('has value equality for complete statement contents', () {
    final entries = [statementTransaction()];
    expect(
      statementFixture(entries: entries),
      statementFixture(entries: entries),
    );
    expect(statementFixture(entries: entries), isNot(statementFixture()));
    expect(
      statementFixture(),
      isNot(statementFixture(range: StatementDateRange.thisMonth)),
    );
    expect(statementFixture().hashCode, statementFixture().hashCode);
  });
}
