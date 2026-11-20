import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statement_fixtures.dart';

void main() {
  test('all includes dates without bounds', () {
    for (final date in [DateTime(2000), DateTime(2100)]) {
      expect(StatementDateRange.all.contains(date, now: statementNow), isTrue);
    }
  });

  test('last 30 days includes whole boundary days but not tomorrow', () {
    final range = StatementDateRange.last30Days;
    for (final (date, included) in [
      (DateTime(2026, 10, 21, 23, 59, 59), false),
      (DateTime(2026, 10, 22), true),
      (DateTime(2026, 11, 20, 23, 59, 59), true),
      (DateTime(2026, 11, 21), false),
    ]) {
      expect(range.contains(date, now: statementNow), included);
    }
  });

  test('last 30 days crosses a year boundary using calendar arithmetic', () {
    final now = DateTime(2026, 1, 10);
    expect(
      StatementDateRange.last30Days.contains(DateTime(2025, 12, 12), now: now),
      isTrue,
    );
    expect(
      StatementDateRange.last30Days.contains(DateTime(2025, 12, 11), now: now),
      isFalse,
    );
  });

  test('this month includes the entire month including leap day', () {
    final now = DateTime(2024, 2, 10);
    for (final (date, included) in [
      (DateTime(2024, 1, 31, 23, 59), false),
      (DateTime(2024, 2), true),
      (DateTime(2024, 2, 29, 23, 59, 59), true),
      (DateTime(2024, 3), false),
    ]) {
      expect(StatementDateRange.thisMonth.contains(date, now: now), included);
    }
  });

  test('custom normalizes time and includes both full boundary days', () {
    final range = StatementDateRange.custom(
      start: DateTime(2026, 11, 1, 15),
      end: DateTime(2026, 11, 3, 10),
    );
    expect(range.start, DateTime(2026, 11, 1));
    expect(range.end, DateTime(2026, 11, 3));
    for (final (date, included) in [
      (DateTime(2026, 10, 31, 23, 59), false),
      (DateTime(2026, 11, 1), true),
      (DateTime(2026, 11, 3, 23, 59, 59, 999, 999), true),
      (DateTime(2026, 11, 4), false),
    ]) {
      expect(range.contains(date, now: statementNow), included);
    }
  });

  test('same-day custom range is valid even with reversed clock times', () {
    final range = StatementDateRange.custom(
      start: DateTime(2026, 11, 1, 23),
      end: DateTime(2026, 11, 1, 1),
    );
    expect(range.contains(DateTime(2026, 11, 1), now: statementNow), isTrue);
  });

  test('custom rejects reversed calendar days', () {
    expect(
      () => StatementDateRange.custom(
        start: DateTime(2026, 11, 2),
        end: DateTime(2026, 11, 1),
      ),
      throwsArgumentError,
    );
  });

  test('UTC timestamps are compared by their local calendar day', () {
    final instant = DateTime.utc(2026, 11, 1, 23, 30);
    final local = instant.toLocal();
    final range = StatementDateRange.custom(start: local, end: local);
    expect(range.contains(instant, now: statementNow), isTrue);
    expect(range, StatementDateRange.custom(start: instant, end: instant));
  });

  test('equality includes range type and normalized custom dates', () {
    expect(StatementDateRange.all, isNot(StatementDateRange.thisMonth));
    final range = StatementDateRange.custom(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 2),
    );
    expect(
      range,
      StatementDateRange.custom(
        start: DateTime(2026, 11, 1, 12),
        end: DateTime(2026, 11, 2, 20),
      ),
    );
    expect(
      range.hashCode,
      StatementDateRange.custom(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 2),
      ).hashCode,
    );
  });
}
