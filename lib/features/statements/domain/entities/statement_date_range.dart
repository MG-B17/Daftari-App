import 'package:equatable/equatable.dart';

enum StatementDateRangeType { all, last30Days, thisMonth, custom }

class StatementDateRange extends Equatable {
  const StatementDateRange._(this.type, [this.start, this.end]);

  static const all = StatementDateRange._(StatementDateRangeType.all);
  static const last30Days = StatementDateRange._(
    StatementDateRangeType.last30Days,
  );
  static const thisMonth = StatementDateRange._(
    StatementDateRangeType.thisMonth,
  );

  factory StatementDateRange.custom({
    required DateTime start,
    required DateTime end,
  }) {
    final first = _day(start);
    final last = _day(end);
    if (first.isAfter(last)) {
      throw ArgumentError('Statement range start must not follow end.');
    }
    return StatementDateRange._(StatementDateRangeType.custom, first, last);
  }

  final StatementDateRangeType type;
  final DateTime? start;
  final DateTime? end;

  bool contains(DateTime date, {required DateTime now}) {
    final day = _day(date);
    final today = _day(now);
    final (first, last) = switch (type) {
      StatementDateRangeType.all => (null, null),
      StatementDateRangeType.last30Days => (
        DateTime(today.year, today.month, today.day - 29),
        today,
      ),
      StatementDateRangeType.thisMonth => (
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1, 0),
      ),
      StatementDateRangeType.custom => (start, end),
    };
    return (first == null || !day.isBefore(first)) &&
        (last == null || !day.isAfter(last));
  }

  static DateTime _day(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  List<Object?> get props => [type, start, end];
}
