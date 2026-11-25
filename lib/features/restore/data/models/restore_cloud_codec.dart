import '../../../backup/data/models/backup_batch_codec.dart';
import '../../domain/entities/restore_entities.dart';

/// Pure wire codec for the Phase 13 Supabase cloud restore and authority
/// transfer RPCs (`read_confirmed_backup_snapshot`,
/// `transfer_backup_authority`, and `find_backup_authority_transfer`).
abstract final class RestoreCloudCodec {
  static Map<String, dynamic> toReadSnapshotRpcParams({
    String? expectedVersion,
  }) => {'p_expected_version': expectedVersion};

  static Map<String, dynamic> toTransferAuthorityRpcParams({
    required String requestId,
    required String targetDeviceId,
    required String targetDeviceSecret,
    required String expectedVersion,
    required String expectedActiveDeviceId,
  }) => {
    'p_request_id': requestId,
    'p_target_device_id': targetDeviceId,
    'p_target_device_secret': targetDeviceSecret,
    'p_expected_version': expectedVersion,
    'p_expected_active_device_id': expectedActiveDeviceId,
  };

  static Map<String, dynamic> toFindAuthorityTransferRpcParams({
    required String requestId,
    required String targetDeviceId,
    required String targetDeviceSecret,
  }) => {
    'p_request_id': requestId,
    'p_target_device_id': targetDeviceId,
    'p_target_device_secret': targetDeviceSecret,
  };

  static RestoreCloudSnapshotReadResult parseReadSnapshotResponse(
    Object? raw, {
    required String ownerUserId,
    String? expectedVersion,
  }) {
    final map = _requireJsonMap(raw);
    switch (map['status']) {
      case 'missing_backup':
        return const RestoreCloudSnapshotMissing();
      case 'version_changed':
        return RestoreCloudSnapshotVersionChanged(
          preview: _parsePreview(map, ownerUserId: ownerUserId),
        );
      case 'ready':
        final preview = _parsePreview(map, ownerUserId: ownerUserId);
        if (expectedVersion != null && preview.version != expectedVersion) {
          return RestoreCloudSnapshotVersionChanged(preview: preview);
        }
        final customers = _readList(
          map['customers'],
          BackupBatchCodec.customerFromJson,
        );
        final transactions = _readList(
          map['transactions'],
          BackupBatchCodec.transactionFromJson,
        );
        final auditLogs = _readList(
          map['audit_logs'],
          BackupBatchCodec.auditLogFromJson,
        );

        final activeCustomers = customers.where((c) => !c.isDeleted).length;
        final deletedCustomers = customers.where((c) => c.isDeleted).length;
        final activeTransactions = transactions
            .where((t) => !t.isDeleted)
            .length;
        final deletedTransactions = transactions
            .where((t) => t.isDeleted)
            .length;

        if (activeCustomers != preview.customerCount ||
            deletedCustomers != preview.deletedCustomerCount ||
            activeTransactions != preview.transactionCount ||
            deletedTransactions != preview.deletedTransactionCount ||
            auditLogs.length != preview.auditLogCount) {
          throw const FormatException(
            'Snapshot record counts do not match returned rows',
          );
        }

        return RestoreCloudSnapshotFound(
          snapshot: CloudBackupSnapshot(
            preview: preview,
            customers: customers,
            transactions: transactions,
            auditLogs: auditLogs,
          ),
        );
      default:
        throw const FormatException('Unexpected cloud snapshot read status');
    }
  }

  static RestoreAuthorityTransferResult parseTransferAuthorityResponse(
    Object? raw, {
    required String expectedRequestId,
    required String expectedTargetDeviceId,
  }) {
    final map = _requireJsonMap(raw);
    return switch (map['status']) {
      'missing_backup' => const RestoreAuthorityMissingBackup(),
      'precondition_failed' => RestoreAuthorityPreconditionFailed(
        reason: _parsePreconditionReason(_requireString(map, 'reason')),
        currentVersion: _requireString(map, 'current_version'),
        activeDeviceId: _requireString(map, 'active_device_id'),
        confirmedAt: _requireUtcDateTime(map, 'confirmed_at'),
      ),
      'transferred' => _parseTransferred(
        map,
        expectedRequestId: expectedRequestId,
        expectedTargetDeviceId: expectedTargetDeviceId,
      ),
      _ => throw const FormatException('Unexpected authority transfer status'),
    };
  }

  static RestoreAuthorityTransferred? parseFindAuthorityTransferResponse(
    Object? raw, {
    required String expectedRequestId,
    required String expectedTargetDeviceId,
  }) {
    final map = _requireJsonMap(raw);
    return switch (map['status']) {
      'not_found' => null,
      'transferred' => _parseTransferred(
        map,
        expectedRequestId: expectedRequestId,
        expectedTargetDeviceId: expectedTargetDeviceId,
      ),
      _ => throw const FormatException('Unexpected transfer lookup status'),
    };
  }

  static CloudBackupSnapshotPreview _parsePreview(
    Map<String, dynamic> map, {
    required String ownerUserId,
  }) => CloudBackupSnapshotPreview(
    version: _requireString(map, 'version'),
    ownerUserId: ownerUserId,
    activeDeviceId: _requireString(map, 'active_device_id'),
    confirmedAt: _requireUtcDateTime(map, 'confirmed_at'),
    customerCount: _requireNonNegativeInt(map, 'customer_count'),
    deletedCustomerCount: _requireNonNegativeInt(map, 'deleted_customer_count'),
    transactionCount: _requireNonNegativeInt(map, 'transaction_count'),
    deletedTransactionCount: _requireNonNegativeInt(
      map,
      'deleted_transaction_count',
    ),
    auditLogCount: _requireNonNegativeInt(map, 'audit_log_count'),
  );

  static RestoreAuthorityTransferred _parseTransferred(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required String expectedTargetDeviceId,
  }) {
    final requestId = _requireString(map, 'request_id');
    final activeDeviceId = _requireString(map, 'active_device_id');
    if (requestId != expectedRequestId ||
        activeDeviceId != expectedTargetDeviceId) {
      throw const FormatException(
        'Mismatched transfer confirmation request_id or active_device_id',
      );
    }
    return RestoreAuthorityTransferred(
      requestId: requestId,
      version: _requireString(map, 'version'),
      activeDeviceId: activeDeviceId,
      confirmedAt: _requireUtcDateTime(map, 'confirmed_at'),
      transferredAt: _requireUtcDateTime(map, 'transferred_at'),
    );
  }

  static RestorePreconditionFailureReason _parsePreconditionReason(
    String value,
  ) => switch (value) {
    'version_changed' => RestorePreconditionFailureReason.versionChanged,
    'active_device_changed' =>
      RestorePreconditionFailureReason.activeDeviceChanged,
    _ => throw FormatException('Unknown precondition failure reason: $value'),
  };

  static Map<String, dynamic> _requireJsonMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
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

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid string field: $key');
    }
    return value;
  }

  static int _requireNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw FormatException(
        'Missing or invalid non-negative integer field: $key',
      );
    }
    return value;
  }

  static DateTime _requireUtcDateTime(Map<String, dynamic> json, String key) =>
      DateTime.parse(_requireString(json, key)).toUtc();
}
