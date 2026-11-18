import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/transaction_entity.dart';

abstract final class TransactionMapper {
  static TransactionEntity toEntity(TransactionRecord record) =>
      TransactionEntity(
        id: record.id,
        customerId: record.customerId,
        type: switch (record.type) {
          TransactionTypes.credit => TransactionType.credit,
          TransactionTypes.payment => TransactionType.payment,
          _ => throw const DatabaseException(),
        },
        amountPiasters: record.amountPiasters,
        transactionDate: record.transactionDate,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        note: record.note,
      );

  static String toDatabaseType(TransactionType type) => switch (type) {
    TransactionType.credit => TransactionTypes.credit,
    TransactionType.payment => TransactionTypes.payment,
  };
}
