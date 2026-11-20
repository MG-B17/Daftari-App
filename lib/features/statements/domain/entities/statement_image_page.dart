import '../../../transactions/domain/entities/transaction_entity.dart';

class StatementImagePage {
  StatementImagePage({
    required Iterable<TransactionEntity> entries,
    required this.number,
    required this.total,
  }) : entries = List.unmodifiable(entries);

  final List<TransactionEntity> entries;
  final int number;
  final int total;
  bool get isFirst => number == 1;
}

abstract final class StatementImagePaginator {
  static List<StatementImagePage> paginate(List<TransactionEntity> entries) {
    final groups = <List<TransactionEntity>>[];
    var current = <TransactionEntity>[];
    var used = 0;
    for (final entry in entries) {
      // Count explicit line breaks as well as conservative wrapping estimates.
      final lines = (entry.note ?? '')
          .split('\n')
          .fold<int>(
            0,
            (sum, line) =>
                sum + (line.runes.length / 28).ceil().clamp(1, 10000),
          );
      final weight = 2 + lines;
      final budget = groups.isEmpty ? 14 : 20;
      if (current.isNotEmpty && used + weight > budget) {
        groups.add(current);
        current = [];
        used = 0;
      }
      current.add(entry);
      used += weight;
    }
    if (current.isNotEmpty || groups.isEmpty) groups.add(current);
    return List.unmodifiable([
      for (var i = 0; i < groups.length; i++)
        StatementImagePage(
          entries: groups[i],
          number: i + 1,
          total: groups.length,
        ),
    ]);
  }
}
