import 'dart:convert';

import '../../../../core/errors/app_exception.dart';
import '../../../backup/domain/entities/backup_batch.dart';
import '../../data/models/restore_cloud_codec.dart';
import '../entities/restore_entities.dart';

/// Pure pre-commit validator for confirmed cloud snapshots prior to staging or
/// atomic local Drift installation.
///
/// Validates format, account ownership, version binding, unique record IDs,
/// parent-child foreign key references (including soft-deleted parent
/// tombstones), preview count consistency, and all supported field values.
abstract final class RestoreSnapshotValidator {
  /// Decodes and validates a raw JSON snapshot payload (either a JSON string or
  /// decoded map) for [expectedOwnerUserId] and optional [expectedVersion].
  ///
  /// Throws [ValidationException] if any format, ownership, uniqueness, parent
  /// reference, or field constraint is violated.
  static CloudBackupSnapshot parseAndValidatePayload(
    Object? rawPayload, {
    required String expectedOwnerUserId,
    String? expectedVersion,
  }) {
    final trimmedOwner = expectedOwnerUserId.trim();
    final trimmedVersion = expectedVersion?.trim();
    if (trimmedOwner.isEmpty ||
        (trimmedVersion != null && trimmedVersion.isEmpty)) {
      throw const ValidationException();
    }

    final Object? decoded;
    if (rawPayload is String) {
      try {
        decoded = jsonDecode(rawPayload);
      } on FormatException {
        throw const ValidationException();
      }
    } else {
      decoded = rawPayload;
    }

    if (decoded is Map) {
      final rawOwner = decoded['owner_user_id'];
      if (rawOwner != null &&
          (rawOwner is! String || rawOwner.trim() != trimmedOwner)) {
        throw const ValidationException();
      }
    }

    final RestoreCloudSnapshotReadResult parsed;
    try {
      parsed = RestoreCloudCodec.parseReadSnapshotResponse(
        decoded,
        ownerUserId: trimmedOwner,
        expectedVersion: trimmedVersion,
      );
    } on FormatException {
      throw const ValidationException();
    }

    if (parsed is! RestoreCloudSnapshotFound) {
      throw const ValidationException();
    }

    validate(
      parsed.snapshot,
      expectedOwnerUserId: trimmedOwner,
      expectedVersion: trimmedVersion,
    );
    return parsed.snapshot;
  }

  /// Validates a [CloudBackupSnapshot] before any local database mutation.
  ///
  /// Throws [ValidationException] if any format, ownership, version, unique ID,
  /// parent reference, or field constraint is violated.
  static void validate(
    CloudBackupSnapshot snapshot, {
    String? expectedOwnerUserId,
    String? expectedVersion,
  }) {
    final preview = snapshot.preview;
    final version = preview.version.trim();
    final ownerUserId = preview.ownerUserId.trim();
    final activeDeviceId = preview.activeDeviceId.trim();

    if (version.isEmpty ||
        version != preview.version ||
        ownerUserId.isEmpty ||
        ownerUserId != preview.ownerUserId ||
        activeDeviceId.isEmpty ||
        activeDeviceId != preview.activeDeviceId) {
      throw const ValidationException();
    }

    if (expectedOwnerUserId != null &&
        ownerUserId != expectedOwnerUserId.trim()) {
      throw const ValidationException();
    }

    if (expectedVersion != null && version != expectedVersion.trim()) {
      throw const ValidationException();
    }

    final customerIds = <String>{};
    var activeCustomers = 0;
    var deletedCustomers = 0;

    for (final customer in snapshot.customers) {
      _validateCustomer(customer);
      if (!customerIds.add(customer.id)) {
        throw const ValidationException();
      }
      if (customer.isDeleted) {
        deletedCustomers++;
      } else {
        activeCustomers++;
      }
    }

    if (activeCustomers != preview.customerCount ||
        deletedCustomers != preview.deletedCustomerCount) {
      throw const ValidationException();
    }

    final transactionIds = <String>{};
    var activeTransactions = 0;
    var deletedTransactions = 0;

    for (final tx in snapshot.transactions) {
      _validateTransaction(tx);
      if (!customerIds.contains(tx.customerId)) {
        throw const ValidationException();
      }
      if (!transactionIds.add(tx.id)) {
        throw const ValidationException();
      }
      if (tx.isDeleted) {
        deletedTransactions++;
      } else {
        activeTransactions++;
      }
    }

    if (activeTransactions != preview.transactionCount ||
        deletedTransactions != preview.deletedTransactionCount) {
      throw const ValidationException();
    }

    final auditIds = <String>{};
    for (final audit in snapshot.auditLogs) {
      _validateAuditLog(audit);
      if (!transactionIds.contains(audit.transactionId)) {
        throw const ValidationException();
      }
      if (!auditIds.add(audit.id)) {
        throw const ValidationException();
      }
    }

    if (snapshot.auditLogs.length != preview.auditLogCount) {
      throw const ValidationException();
    }
  }

  static void _validateCustomer(BackupCustomerRecord customer) {
    final id = customer.id.trim();
    final name = customer.name.trim();
    if (id.isEmpty ||
        id != customer.id ||
        name.isEmpty ||
        customer.localRevision < 1) {
      throw const ValidationException();
    }
    if (customer.phone != null && customer.phone!.trim().isEmpty) {
      throw const ValidationException();
    }
    if (customer.notes != null && customer.notes!.trim().isEmpty) {
      throw const ValidationException();
    }
  }

  static void _validateTransaction(BackupTransactionRecord tx) {
    final id = tx.id.trim();
    final customerId = tx.customerId.trim();
    if (id.isEmpty ||
        id != tx.id ||
        customerId.isEmpty ||
        customerId != tx.customerId ||
        tx.amountPiasters <= 0 ||
        tx.localRevision < 1) {
      throw const ValidationException();
    }
    if (tx.note != null && tx.note!.trim().isEmpty) {
      throw const ValidationException();
    }
  }

  static void _validateAuditLog(BackupAuditLogRecord audit) {
    final id = audit.id.trim();
    final transactionId = audit.transactionId.trim();
    if (id.isEmpty ||
        id != audit.id ||
        transactionId.isEmpty ||
        transactionId != audit.transactionId ||
        audit.previousAmountPiasters <= 0 ||
        audit.localRevision < 1) {
      throw const ValidationException();
    }
    if (audit.previousNote != null && audit.previousNote!.trim().isEmpty) {
      throw const ValidationException();
    }
  }
}
