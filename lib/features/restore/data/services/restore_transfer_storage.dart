import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../backup/data/models/backup_batch_codec.dart';
import '../../domain/entities/restore_entities.dart';

/// Durable payload combining [PendingRestoreTransfer] metadata and the
/// validated [CloudBackupSnapshot] staged before requesting server takeover.
final class PersistedRestoreTransferPayload extends Equatable {
  const PersistedRestoreTransferPayload({
    required this.transfer,
    required this.stagedSnapshot,
  });

  final PendingRestoreTransfer transfer;
  final CloudBackupSnapshot stagedSnapshot;

  PersistedRestoreTransferPayload copyWith({
    PendingRestoreTransfer? transfer,
    CloudBackupSnapshot? stagedSnapshot,
  }) => PersistedRestoreTransferPayload(
    transfer: transfer ?? this.transfer,
    stagedSnapshot: stagedSnapshot ?? this.stagedSnapshot,
  );

  @override
  List<Object?> get props => [transfer, stagedSnapshot];
}

/// Persists in-flight restore and device-authority transfer progress plus the
/// validated cloud snapshot across app restarts and background worker runs.
///
/// Storing the pending transfer in [FlutterSecureStorage] ensures both the
/// foreground UI isolate and the headless Android `BackupWorker` isolate can
/// observe an unfinished transfer and keep uploads blocked on the receiving
/// phone until local SQLite installation completes.
class RestoreTransferStorage {
  const RestoreTransferStorage(this._secureStorage);

  static const pendingTransferKey = 'daftari_restore_pending_transfer_v1';

  final FlutterSecureStorage _secureStorage;

  /// Returns `true` while a persisted restore/takeover transfer is awaiting
  /// server confirmation or local SQLite installation.
  Future<bool> hasPendingTransfer() async {
    final raw = await _secureStorage.read(key: pendingTransferKey);
    return raw != null && raw.trim().isNotEmpty;
  }

  /// Reads the persisted [PersistedRestoreTransferPayload], or `null` if none
  /// is currently active.
  Future<PersistedRestoreTransferPayload?> readPendingTransfer() async {
    final raw = await _secureStorage.read(key: pendingTransferKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return _decodePayload(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Durably persists [transfer] and [stagedSnapshot] before requesting server
  /// takeover or local installation.
  Future<void> writePendingTransfer({
    required PendingRestoreTransfer transfer,
    required CloudBackupSnapshot stagedSnapshot,
  }) async {
    final encoded = jsonEncode(
      _encodePayload(
        PersistedRestoreTransferPayload(
          transfer: transfer,
          stagedSnapshot: stagedSnapshot,
        ),
      ),
    );
    await _secureStorage.write(key: pendingTransferKey, value: encoded);
  }

  /// Advances the persisted transfer stage (and optionally updates
  /// [cloudPreview] once server takeover commits).
  Future<PersistedRestoreTransferPayload?> updateStage({
    required String requestId,
    required RestoreTransferStage stage,
    CloudBackupSnapshotPreview? cloudPreview,
  }) async {
    final current = await readPendingTransfer();
    if (current == null || current.transfer.requestId != requestId) {
      return null;
    }
    final nextPreview = cloudPreview ?? current.transfer.cloudPreview;
    final nextTransfer = current.transfer.copyWith(
      stage: stage,
      cloudPreview: nextPreview,
    );
    final nextSnapshot = CloudBackupSnapshot(
      preview: nextPreview,
      customers: current.stagedSnapshot.customers,
      transactions: current.stagedSnapshot.transactions,
      auditLogs: current.stagedSnapshot.auditLogs,
    );
    await writePendingTransfer(
      transfer: nextTransfer,
      stagedSnapshot: nextSnapshot,
    );
    return PersistedRestoreTransferPayload(
      transfer: nextTransfer,
      stagedSnapshot: nextSnapshot,
    );
  }

  /// Clears the persisted pending transfer once local installation finishes or
  /// a pre-takeover transfer is cancelled.
  Future<void> clearPendingTransfer({String? requestId}) async {
    if (requestId != null) {
      final current = await readPendingTransfer();
      if (current != null && current.transfer.requestId != requestId) {
        return;
      }
    }
    await _secureStorage.delete(key: pendingTransferKey);
  }

  static Map<String, dynamic> _encodePayload(
    PersistedRestoreTransferPayload payload,
  ) => {
    'transfer': _encodeTransfer(payload.transfer),
    'snapshot': _encodeSnapshot(payload.stagedSnapshot),
  };

  static PersistedRestoreTransferPayload _decodePayload(
    Map<String, dynamic> json,
  ) {
    final transferMap = _requireMap(json['transfer']);
    final snapshotMap = _requireMap(json['snapshot']);
    return PersistedRestoreTransferPayload(
      transfer: _decodeTransfer(transferMap),
      stagedSnapshot: _decodeSnapshot(snapshotMap),
    );
  }

  static Map<String, dynamic> _encodeTransfer(
    PendingRestoreTransfer transfer,
  ) => {
    'request_id': transfer.requestId,
    'owner_user_id': transfer.ownerUserId,
    'target_device_id': transfer.targetDeviceId,
    'expected_version': transfer.expectedVersion,
    'expected_active_device_id': transfer.expectedActiveDeviceId,
    'confirmed_at': transfer.confirmedAt.toUtc().toIso8601String(),
    'requires_takeover': transfer.requiresTakeover,
    'requires_replacement': transfer.requiresReplacement,
    'consented_local_revision_stamp': transfer.consentedLocalRevisionStamp,
    'stage': transfer.stage.name,
    'cloud_preview': _encodePreview(transfer.cloudPreview),
  };

  static PendingRestoreTransfer _decodeTransfer(Map<String, dynamic> json) =>
      PendingRestoreTransfer(
        requestId: json['request_id'] as String,
        ownerUserId: json['owner_user_id'] as String,
        targetDeviceId: json['target_device_id'] as String,
        expectedVersion: json['expected_version'] as String,
        expectedActiveDeviceId: json['expected_active_device_id'] as String,
        confirmedAt: DateTime.parse(json['confirmed_at'] as String).toUtc(),
        requiresTakeover: json['requires_takeover'] as bool,
        requiresReplacement: json['requires_replacement'] as bool,
        consentedLocalRevisionStamp:
            json['consented_local_revision_stamp'] as String,
        stage: _parseStage(json['stage'] as String),
        cloudPreview: _decodePreview(_requireMap(json['cloud_preview'])),
      );

  static Map<String, dynamic> _encodePreview(
    CloudBackupSnapshotPreview preview,
  ) => {
    'version': preview.version,
    'owner_user_id': preview.ownerUserId,
    'active_device_id': preview.activeDeviceId,
    'confirmed_at': preview.confirmedAt.toUtc().toIso8601String(),
    'customer_count': preview.customerCount,
    'deleted_customer_count': preview.deletedCustomerCount,
    'transaction_count': preview.transactionCount,
    'deleted_transaction_count': preview.deletedTransactionCount,
    'audit_log_count': preview.auditLogCount,
  };

  static CloudBackupSnapshotPreview _decodePreview(Map<String, dynamic> json) =>
      CloudBackupSnapshotPreview(
        version: json['version'] as String,
        ownerUserId: json['owner_user_id'] as String,
        activeDeviceId: json['active_device_id'] as String,
        confirmedAt: DateTime.parse(json['confirmed_at'] as String).toUtc(),
        customerCount: json['customer_count'] as int,
        deletedCustomerCount: json['deleted_customer_count'] as int,
        transactionCount: json['transaction_count'] as int,
        deletedTransactionCount: json['deleted_transaction_count'] as int,
        auditLogCount: json['audit_log_count'] as int,
      );

  static Map<String, dynamic> _encodeSnapshot(CloudBackupSnapshot snapshot) => {
    'preview': _encodePreview(snapshot.preview),
    'customers': snapshot.customers
        .map(BackupBatchCodec.customerToJson)
        .toList(growable: false),
    'transactions': snapshot.transactions
        .map(BackupBatchCodec.transactionToJson)
        .toList(growable: false),
    'audit_logs': snapshot.auditLogs
        .map(BackupBatchCodec.auditLogToJson)
        .toList(growable: false),
  };

  static CloudBackupSnapshot _decodeSnapshot(Map<String, dynamic> json) {
    final preview = _decodePreview(_requireMap(json['preview']));
    final customers = (json['customers'] as List<dynamic>)
        .map((e) => BackupBatchCodec.customerFromJson(_requireMap(e)))
        .toList(growable: false);
    final transactions = (json['transactions'] as List<dynamic>)
        .map((e) => BackupBatchCodec.transactionFromJson(_requireMap(e)))
        .toList(growable: false);
    final auditLogs = (json['audit_logs'] as List<dynamic>)
        .map((e) => BackupBatchCodec.auditLogFromJson(_requireMap(e)))
        .toList(growable: false);
    return CloudBackupSnapshot(
      preview: preview,
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
    );
  }

  static RestoreTransferStage _parseStage(String value) => switch (value) {
    'takeoverPending' => RestoreTransferStage.takeoverPending,
    'takeoverConfirmed' => RestoreTransferStage.takeoverConfirmed,
    'installingLocally' => RestoreTransferStage.installingLocally,
    _ => throw FormatException('Unknown restore transfer stage: $value'),
  };

  static Map<String, dynamic> _requireMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const FormatException('Expected JSON map');
  }
}
