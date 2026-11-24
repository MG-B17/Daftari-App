import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/backup_batch.dart';
import '../../domain/entities/backup_run_result.dart';
import '../../domain/entities/backup_schedule.dart';

/// Pure serialization helpers shared between Drift durable in-flight batch
/// storage and Supabase RPC payloads.
abstract final class BackupBatchCodec {
  static BackupCustomerRecord customerFromRow(Customer row) =>
      BackupCustomerRecord(
        id: row.id,
        name: row.name,
        phone: row.phone,
        notes: row.notes,
        createdAt: row.createdAt.toUtc(),
        updatedAt: row.updatedAt.toUtc(),
        deletedAt: row.deletedAt?.toUtc(),
        localRevision: row.localRevision,
      );

  static BackupTransactionRecord transactionFromRow(TransactionRecord row) =>
      BackupTransactionRecord(
        id: row.id,
        customerId: row.customerId,
        type: _parseTransactionType(row.type),
        amountPiasters: row.amountPiasters,
        note: row.note,
        transactionDate: row.transactionDate.toUtc(),
        createdAt: row.createdAt.toUtc(),
        updatedAt: row.updatedAt.toUtc(),
        deletedAt: row.deletedAt?.toUtc(),
        localRevision: row.localRevision,
      );

  static BackupAuditLogRecord auditLogFromRow(TransactionAuditLog row) =>
      BackupAuditLogRecord(
        id: row.id,
        transactionId: row.transactionId,
        action: _parseAuditAction(row.action),
        previousType: _parseTransactionType(row.previousType),
        previousAmountPiasters: row.previousAmountPiasters,
        previousNote: row.previousNote,
        previousTransactionDate: row.previousTransactionDate.toUtc(),
        createdAt: row.createdAt.toUtc(),
        localRevision: row.localRevision,
      );

  static String encodeRecordsPayload({
    required List<BackupCustomerRecord> customers,
    required List<BackupTransactionRecord> transactions,
    required List<BackupAuditLogRecord> auditLogs,
  }) => jsonEncode({
    'customers': customers.map(customerToJson).toList(growable: false),
    'transactions': transactions.map(transactionToJson).toList(growable: false),
    'audit_logs': auditLogs.map(auditLogToJson).toList(growable: false),
  });

  static BackupBatch decodeInFlightRow(BackupInFlightBatchRow row) {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid in-flight batch payload');
    }
    final customers = _readList(decoded['customers'], customerFromJson);
    final transactions = _readList(
      decoded['transactions'],
      transactionFromJson,
    );
    final auditLogs = _readList(decoded['audit_logs'], auditLogFromJson);
    return BackupBatch(
      batchId: row.batchId,
      ownerUserId: row.ownerUserId,
      deviceId: row.deviceId,
      capturedAt: DateTime.parse(row.capturedAtIso).toUtc(),
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
    );
  }

  static Map<String, dynamic> toPublishRpcParams(
    BackupBatch batch, {
    required String deviceSecret,
  }) => {
    'p_batch_id': batch.batchId,
    'p_device_id': batch.deviceId,
    'p_device_secret': deviceSecret,
    'p_captured_at': batch.capturedAt.toUtc().toIso8601String(),
    'p_customers': batch.customers.map(customerToJson).toList(growable: false),
    'p_transactions': batch.transactions
        .map(transactionToJson)
        .toList(growable: false),
    'p_audit_logs': batch.auditLogs.map(auditLogToJson).toList(growable: false),
  };

  static Map<String, dynamic> toFindConfirmationRpcParams({
    required String batchId,
    required String deviceId,
    required String deviceSecret,
  }) => {
    'p_batch_id': batchId,
    'p_device_id': deviceId,
    'p_device_secret': deviceSecret,
  };

  static BackupPublicationResult? parseFindConfirmationResponse(
    Object? raw, {
    required String expectedBatchId,
  }) {
    final map = _requireJsonMap(raw);
    return switch (map['status']) {
      'not_found' => null,
      'inactive_device' => const BackupPublicationInactiveDevice(),
      'confirmed' => _parseConfirmed(map, expectedBatchId: expectedBatchId),
      _ => throw const FormatException('Unexpected backup lookup status'),
    };
  }

  static BackupPublicationResult parsePublishResponse(
    Object? raw, {
    required String expectedBatchId,
  }) {
    final map = _requireJsonMap(raw);
    return switch (map['status']) {
      'inactive_device' => const BackupPublicationInactiveDevice(),
      'confirmed' => _parseConfirmed(map, expectedBatchId: expectedBatchId),
      _ => throw const FormatException('Unexpected backup publication status'),
    };
  }

  static BackupScheduleState scheduleStateFromMetadata(
    BackupMetadataSnapshot snapshot,
  ) => BackupScheduleState(
    schedule: _parseSchedule(snapshot.schedule),
    lastConfirmedAt: _parseOptionalUtc(snapshot.lastConfirmedAtIso),
    nextDueAt: _parseOptionalUtc(snapshot.nextDueAtIso),
  );

  static BackupMetadataSnapshot metadataFromScheduleState(
    BackupScheduleState state, {
    required bool isDeviceActive,
  }) => BackupMetadataSnapshot(
    schedule: state.schedule?.name,
    lastConfirmedAtIso: state.lastConfirmedAt?.toUtc().toIso8601String(),
    nextDueAtIso: state.nextDueAt?.toUtc().toIso8601String(),
    isDeviceActive: isDeviceActive,
  );

  static Map<String, dynamic> customerToJson(BackupCustomerRecord record) => {
    'id': record.id,
    'name': record.name,
    'phone': record.phone,
    'notes': record.notes,
    'created_at': record.createdAt.toUtc().toIso8601String(),
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
    'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
    'local_revision': record.localRevision,
  };

  static BackupCustomerRecord customerFromJson(Map<String, dynamic> json) =>
      BackupCustomerRecord(
        id: _requireString(json, 'id'),
        name: _requireString(json, 'name'),
        phone: _optionalString(json, 'phone'),
        notes: _optionalString(json, 'notes'),
        createdAt: _requireUtcDateTime(json, 'created_at'),
        updatedAt: _requireUtcDateTime(json, 'updated_at'),
        deletedAt: _optionalUtcDateTime(json, 'deleted_at'),
        localRevision: _requirePositiveInt(json, 'local_revision'),
      );

  static Map<String, dynamic> transactionToJson(
    BackupTransactionRecord record,
  ) => {
    'id': record.id,
    'customer_id': record.customerId,
    'type': _transactionTypeToWire(record.type),
    'amount_piasters': record.amountPiasters,
    'note': record.note,
    'transaction_date': record.transactionDate.toUtc().toIso8601String(),
    'created_at': record.createdAt.toUtc().toIso8601String(),
    'updated_at': record.updatedAt.toUtc().toIso8601String(),
    'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
    'local_revision': record.localRevision,
  };

  static BackupTransactionRecord transactionFromJson(
    Map<String, dynamic> json,
  ) => BackupTransactionRecord(
    id: _requireString(json, 'id'),
    customerId: _requireString(json, 'customer_id'),
    type: _parseTransactionType(_requireString(json, 'type')),
    amountPiasters: _requirePositiveInt(json, 'amount_piasters'),
    note: _optionalString(json, 'note'),
    transactionDate: _requireUtcDateTime(json, 'transaction_date'),
    createdAt: _requireUtcDateTime(json, 'created_at'),
    updatedAt: _requireUtcDateTime(json, 'updated_at'),
    deletedAt: _optionalUtcDateTime(json, 'deleted_at'),
    localRevision: _requirePositiveInt(json, 'local_revision'),
  );

  static Map<String, dynamic> auditLogToJson(BackupAuditLogRecord record) => {
    'id': record.id,
    'transaction_id': record.transactionId,
    'action': _auditActionToWire(record.action),
    'previous_type': _transactionTypeToWire(record.previousType),
    'previous_amount_piasters': record.previousAmountPiasters,
    'previous_note': record.previousNote,
    'previous_transaction_date': record.previousTransactionDate
        .toUtc()
        .toIso8601String(),
    'created_at': record.createdAt.toUtc().toIso8601String(),
    'local_revision': record.localRevision,
  };

  static BackupAuditLogRecord auditLogFromJson(Map<String, dynamic> json) =>
      BackupAuditLogRecord(
        id: _requireString(json, 'id'),
        transactionId: _requireString(json, 'transaction_id'),
        action: _parseAuditAction(_requireString(json, 'action')),
        previousType: _parseTransactionType(
          _requireString(json, 'previous_type'),
        ),
        previousAmountPiasters: _requirePositiveInt(
          json,
          'previous_amount_piasters',
        ),
        previousNote: _optionalString(json, 'previous_note'),
        previousTransactionDate: _requireUtcDateTime(
          json,
          'previous_transaction_date',
        ),
        createdAt: _requireUtcDateTime(json, 'created_at'),
        localRevision: _requirePositiveInt(json, 'local_revision'),
      );

  static BackupPublicationConfirmed _parseConfirmed(
    Map<String, dynamic> map, {
    required String expectedBatchId,
  }) {
    final batchId = _requireString(map, 'batch_id');
    if (batchId != expectedBatchId) {
      throw const FormatException('Mismatched confirmed batch_id');
    }
    final confirmedAt = _requireUtcDateTime(map, 'confirmed_at');
    return BackupPublicationConfirmed(
      batchId: batchId,
      confirmedAt: confirmedAt,
    );
  }

  static Map<String, dynamic> _requireJsonMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw const FormatException('Expected JSON object response');
  }

  static List<T> _readList<T>(
    Object? raw,
    T Function(Map<String, dynamic> item) fromJson,
  ) {
    if (raw is! List) {
      throw const FormatException('Expected JSON list');
    }
    return raw
        .map((item) => fromJson(_requireJsonMap(item)))
        .toList(growable: false);
  }

  static String _transactionTypeToWire(TransactionType type) => switch (type) {
    TransactionType.credit => TransactionTypes.credit,
    TransactionType.payment => TransactionTypes.payment,
  };

  static TransactionType _parseTransactionType(String value) => switch (value) {
    TransactionTypes.credit => TransactionType.credit,
    TransactionTypes.payment => TransactionType.payment,
    _ => throw FormatException('Unknown transaction type: $value'),
  };

  static String _auditActionToWire(BackupAuditAction action) =>
      switch (action) {
        BackupAuditAction.edit => TransactionAuditActions.edit,
        BackupAuditAction.delete => TransactionAuditActions.delete,
      };

  static BackupAuditAction _parseAuditAction(String value) => switch (value) {
    TransactionAuditActions.edit => BackupAuditAction.edit,
    TransactionAuditActions.delete => BackupAuditAction.delete,
    _ => throw FormatException('Unknown audit action: $value'),
  };

  static BackupSchedule? _parseSchedule(String? value) => switch (value) {
    null => null,
    'daily' => BackupSchedule.daily,
    'weekly' => BackupSchedule.weekly,
    'monthly' => BackupSchedule.monthly,
    _ => throw FormatException('Unknown backup schedule: $value'),
  };

  static DateTime? _parseOptionalUtc(String? value) =>
      value == null ? null : DateTime.parse(value).toUtc();

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid string field: $key');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid optional string field: $key');
    }
    return value;
  }

  static int _requirePositiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 1) {
      throw FormatException('Missing or invalid positive integer field: $key');
    }
    return value;
  }

  static DateTime _requireUtcDateTime(Map<String, dynamic> json, String key) =>
      DateTime.parse(_requireString(json, key)).toUtc();

  static DateTime? _optionalUtcDateTime(Map<String, dynamic> json, String key) {
    final value = _optionalString(json, key);
    return value == null ? null : DateTime.parse(value).toUtc();
  }
}
