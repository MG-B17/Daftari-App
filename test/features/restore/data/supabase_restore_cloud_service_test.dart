import 'dart:async';
import 'dart:io';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_bootstrap.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/backup/data/repositories/supabase_backup_cloud_publisher.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/restore/data/repositories/supabase_restore_cloud_service.dart';
import 'package:daftariapp/features/restore/domain/entities/restore_entities.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.user});

  AuthUser? user;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser?> getCurrentUser() async => user;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => const Stream.empty();

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut({String? expectedUserId}) async {
    user = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();
}

final class _ServerAccountState {
  _ServerAccountState({
    required this.activeDeviceId,
    required this.deviceSecretHash,
  });

  String activeDeviceId;
  String deviceSecretHash;
  DateTime? lastConfirmedAt;
  int confirmedVersion = 0;
  final Map<String, ({String deviceId, DateTime confirmedAt})> batches = {};
  final Map<String, Map<String, dynamic>> customers = {};
  final Map<String, Map<String, dynamic>> transactions = {};
  final Map<String, Map<String, dynamic>> auditLogs = {};
  final Map<
    String,
    ({
      String previousDeviceId,
      String targetDeviceId,
      String targetSecretHash,
      String version,
      DateTime confirmedAt,
      DateTime transferredAt,
    })
  >
  transfers = {};
}

/// In-memory simulation of the Phase 12 + Phase 13 Supabase RPC backend that
/// derives account identity strictly from the caller's session and serializes
/// `publish_backup_batch`, `find_backup_batch_confirmation`,
/// `read_confirmed_backup_snapshot`, `transfer_backup_authority`, and
/// `find_backup_authority_transfer` per account.
class _SimulatedSupabaseRpcServer {
  DateTime now = DateTime.utc(2026, 11, 25, 10);
  final Map<String, _ServerAccountState> _accounts = {};
  final Map<String, Future<void>> _accountLocks = {};
  final List<({String userId, String fn, Map<String, dynamic> params})> calls =
      [];

  Future<void> Function(String fn, Map<String, dynamic> params)? onRpcEntered;

  static String _hashSecret(String secret) => 'sha256:${secret.trim()}';

  void seedZeroRowConfirmedAccount({
    required String userId,
    required String activeDeviceId,
    required String deviceSecret,
    required DateTime confirmedAt,
  }) {
    final account =
        _ServerAccountState(
            activeDeviceId: activeDeviceId,
            deviceSecretHash: _hashSecret(deviceSecret),
          )
          ..lastConfirmedAt = confirmedAt.toUtc()
          ..confirmedVersion = 1;
    _accounts[userId] = account;
  }

  BackupRpcCaller callerForSession(_FakeAuthService authService) =>
      (functionName, {required params}) async {
        final user = authService.currentUser;
        if (user == null || !user.emailVerified) {
          throw const sb.PostgrestException(
            message: 'Authentication and verified email required',
            code: '42501',
          );
        }
        // Verify no client RPC ever passes user_id in params; account identity
        // must come solely from the session.
        if (params.containsKey('p_user_id') || params.containsKey('user_id')) {
          throw const sb.PostgrestException(
            message: 'Client must not supply user_id',
            code: '22023',
          );
        }
        calls.add((userId: user.id, fn: functionName, params: params));
        return _withAccountLock(user.id, () async {
          if (onRpcEntered case final hook?) {
            await hook(functionName, params);
          }
          return _handleRpc(user.id, functionName, params);
        });
      };

  Future<T> _withAccountLock<T>(
    String userId,
    Future<T> Function() action,
  ) async {
    final previous = _accountLocks[userId];
    final completer = Completer<void>();
    _accountLocks[userId] = completer.future;
    if (previous != null) {
      await previous;
    }
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_accountLocks[userId], completer.future)) {
        _accountLocks.remove(userId);
      }
    }
  }

  Object? _handleRpc(
    String userId,
    String functionName,
    Map<String, dynamic> params,
  ) {
    switch (functionName) {
      case SupabaseBackupCloudPublisher.publishBatchRpc:
        return _publishBatch(userId, params);
      case SupabaseBackupCloudPublisher.findBatchConfirmationRpc:
        return _findBatchConfirmation(userId, params);
      case SupabaseRestoreCloudService.readConfirmedSnapshotRpc:
        return _readConfirmedSnapshot(userId, params);
      case SupabaseRestoreCloudService.transferBackupAuthorityRpc:
        return _transferBackupAuthority(userId, params);
      case SupabaseRestoreCloudService.findAuthorityTransferRpc:
        return _findAuthorityTransfer(userId, params);
      default:
        throw StateError('Unknown RPC: $functionName');
    }
  }

  Map<String, dynamic> _publishBatch(
    String userId,
    Map<String, dynamic> params,
  ) {
    final batchId = params['p_batch_id'] as String;
    final deviceId = params['p_device_id'] as String;
    final deviceSecret = params['p_device_secret'] as String;
    final secretHash = _hashSecret(deviceSecret);
    final customers = (params['p_customers'] as List)
        .cast<Map<String, dynamic>>();
    final transactions = (params['p_transactions'] as List)
        .cast<Map<String, dynamic>>();
    final auditLogs = (params['p_audit_logs'] as List)
        .cast<Map<String, dynamic>>();

    final account = _accounts.putIfAbsent(
      userId,
      () => _ServerAccountState(
        activeDeviceId: deviceId,
        deviceSecretHash: secretHash,
      ),
    );

    if (account.activeDeviceId != deviceId ||
        account.deviceSecretHash != secretHash) {
      return {'status': 'inactive_device'};
    }

    if (account.batches[batchId] case final existing?) {
      if (existing.deviceId != deviceId) {
        throw const sb.PostgrestException(
          message: 'Batch belongs to another device',
          code: '22023',
        );
      }
      return {
        'status': 'confirmed',
        'batch_id': batchId,
        'confirmed_at': existing.confirmedAt.toUtc().toIso8601String(),
      };
    }

    for (final c in customers) {
      final id = c['id'] as String;
      final existing = account.customers[id];
      if (existing == null ||
          (existing['local_revision'] as int) < (c['local_revision'] as int)) {
        account.customers[id] = Map<String, dynamic>.from(c);
      }
    }
    for (final t in transactions) {
      final id = t['id'] as String;
      final customerId = t['customer_id'] as String;
      if (!account.customers.containsKey(customerId)) {
        throw const sb.PostgrestException(
          message: 'Missing parent customer',
          code: '23503',
        );
      }
      final existing = account.transactions[id];
      if (existing == null ||
          (existing['local_revision'] as int) < (t['local_revision'] as int)) {
        account.transactions[id] = Map<String, dynamic>.from(t);
      }
    }
    for (final a in auditLogs) {
      final id = a['id'] as String;
      final txId = a['transaction_id'] as String;
      if (!account.transactions.containsKey(txId)) {
        throw const sb.PostgrestException(
          message: 'Missing parent transaction',
          code: '23503',
        );
      }
      account.auditLogs.putIfAbsent(id, () => Map<String, dynamic>.from(a));
    }

    final confirmedAt = now.toUtc();
    now = now.add(const Duration(seconds: 1));
    account.batches[batchId] = (deviceId: deviceId, confirmedAt: confirmedAt);
    account.lastConfirmedAt = confirmedAt;
    account.confirmedVersion += 1;

    return {
      'status': 'confirmed',
      'batch_id': batchId,
      'confirmed_at': confirmedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _findBatchConfirmation(
    String userId,
    Map<String, dynamic> params,
  ) {
    final batchId = params['p_batch_id'] as String;
    final deviceId = params['p_device_id'] as String;
    final deviceSecret = params['p_device_secret'] as String;
    final secretHash = _hashSecret(deviceSecret);

    final account = _accounts[userId];
    if (account != null &&
        (account.activeDeviceId != deviceId ||
            account.deviceSecretHash != secretHash)) {
      return {'status': 'inactive_device'};
    }
    final batch = account?.batches[batchId];
    if (batch == null || batch.deviceId != deviceId) {
      return {'status': 'not_found'};
    }
    return {
      'status': 'confirmed',
      'batch_id': batchId,
      'confirmed_at': batch.confirmedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _readConfirmedSnapshot(
    String userId,
    Map<String, dynamic> params,
  ) {
    final expectedVersion = params['p_expected_version'] as String?;
    final account = _accounts[userId];
    if (account == null ||
        account.lastConfirmedAt == null ||
        account.confirmedVersion < 1) {
      return {'status': 'missing_backup'};
    }

    final version = 'v-${account.confirmedVersion}';
    final customers = account.customers.values.toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final transactions = account.transactions.values.toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final auditLogs = account.auditLogs.values.toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

    final customerCount = customers
        .where((c) => c['deleted_at'] == null)
        .length;
    final deletedCustomerCount = customers
        .where((c) => c['deleted_at'] != null)
        .length;
    final transactionCount = transactions
        .where((t) => t['deleted_at'] == null)
        .length;
    final deletedTransactionCount = transactions
        .where((t) => t['deleted_at'] != null)
        .length;

    if (expectedVersion != null && expectedVersion != version) {
      return {
        'status': 'version_changed',
        'version': version,
        'active_device_id': account.activeDeviceId,
        'confirmed_at': account.lastConfirmedAt!.toUtc().toIso8601String(),
        'customer_count': customerCount,
        'deleted_customer_count': deletedCustomerCount,
        'transaction_count': transactionCount,
        'deleted_transaction_count': deletedTransactionCount,
        'audit_log_count': auditLogs.length,
      };
    }

    return {
      'status': 'ready',
      'version': version,
      'active_device_id': account.activeDeviceId,
      'confirmed_at': account.lastConfirmedAt!.toUtc().toIso8601String(),
      'customer_count': customerCount,
      'deleted_customer_count': deletedCustomerCount,
      'transaction_count': transactionCount,
      'deleted_transaction_count': deletedTransactionCount,
      'audit_log_count': auditLogs.length,
      'customers': customers,
      'transactions': transactions,
      'audit_logs': auditLogs,
    };
  }

  Map<String, dynamic> _transferBackupAuthority(
    String userId,
    Map<String, dynamic> params,
  ) {
    final requestId = params['p_request_id'] as String;
    final targetDeviceId = params['p_target_device_id'] as String;
    final targetDeviceSecret = params['p_target_device_secret'] as String;
    final expectedVersion = params['p_expected_version'] as String;
    final expectedActiveDeviceId =
        params['p_expected_active_device_id'] as String;
    final secretHash = _hashSecret(targetDeviceSecret);

    final account = _accounts[userId];
    if (account == null ||
        account.lastConfirmedAt == null ||
        account.confirmedVersion < 1) {
      return {'status': 'missing_backup'};
    }

    if (account.transfers[requestId] case final existing?) {
      if (existing.targetDeviceId != targetDeviceId ||
          existing.targetSecretHash != secretHash ||
          existing.version != expectedVersion ||
          existing.previousDeviceId != expectedActiveDeviceId) {
        throw const sb.PostgrestException(
          message: 'Transfer request_id parameter mismatch',
          code: '22023',
        );
      }
      return {
        'status': 'transferred',
        'request_id': requestId,
        'version': existing.version,
        'active_device_id': existing.targetDeviceId,
        'confirmed_at': existing.confirmedAt.toUtc().toIso8601String(),
        'transferred_at': existing.transferredAt.toUtc().toIso8601String(),
      };
    }

    final currentVersion = 'v-${account.confirmedVersion}';
    if (currentVersion != expectedVersion ||
        account.activeDeviceId != expectedActiveDeviceId) {
      return {
        'status': 'precondition_failed',
        'reason': currentVersion != expectedVersion
            ? 'version_changed'
            : 'active_device_changed',
        'current_version': currentVersion,
        'active_device_id': account.activeDeviceId,
        'confirmed_at': account.lastConfirmedAt!.toUtc().toIso8601String(),
      };
    }

    final transferredAt = now.toUtc();
    now = now.add(const Duration(seconds: 1));
    final previousDeviceId = account.activeDeviceId;
    account.activeDeviceId = targetDeviceId;
    account.deviceSecretHash = secretHash;
    account.transfers[requestId] = (
      previousDeviceId: previousDeviceId,
      targetDeviceId: targetDeviceId,
      targetSecretHash: secretHash,
      version: currentVersion,
      confirmedAt: account.lastConfirmedAt!,
      transferredAt: transferredAt,
    );

    return {
      'status': 'transferred',
      'request_id': requestId,
      'version': currentVersion,
      'active_device_id': targetDeviceId,
      'confirmed_at': account.lastConfirmedAt!.toUtc().toIso8601String(),
      'transferred_at': transferredAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _findAuthorityTransfer(
    String userId,
    Map<String, dynamic> params,
  ) {
    final requestId = params['p_request_id'] as String;
    final targetDeviceId = params['p_target_device_id'] as String;
    final targetDeviceSecret = params['p_target_device_secret'] as String;
    final secretHash = _hashSecret(targetDeviceSecret);

    final existing = _accounts[userId]?.transfers[requestId];
    if (existing == null) {
      return {'status': 'not_found'};
    }
    if (existing.targetDeviceId != targetDeviceId ||
        existing.targetSecretHash != secretHash) {
      throw const sb.PostgrestException(
        message: 'Transfer belongs to another device credential',
        code: '42501',
      );
    }
    return {
      'status': 'transferred',
      'request_id': requestId,
      'version': existing.version,
      'active_device_id': existing.targetDeviceId,
      'confirmed_at': existing.confirmedAt.toUtc().toIso8601String(),
      'transferred_at': existing.transferredAt.toUtc().toIso8601String(),
    };
  }
}

final class _SimulatedPhoneInstallation {
  _SimulatedPhoneInstallation({
    required this.db,
    required this.authService,
    required this.deviceStorage,
    required this.publisher,
    required this.restoreCloud,
    required this.deviceId,
    required this.deviceSecret,
  });

  final AppDatabase db;
  final _FakeAuthService authService;
  final BackupDeviceStorage deviceStorage;
  final SupabaseBackupCloudPublisher publisher;
  final SupabaseRestoreCloudService restoreCloud;
  final String deviceId;
  final String deviceSecret;

  Future<void> dispose() => db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  const userA = '11111111-1111-4111-8111-111111111111';
  const userB = '22222222-2222-4222-8222-222222222222';
  const deviceA1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  const deviceA2 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  const deviceA3 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  const deviceB1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  const deviceB2 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  final secretA1 = 'a1' * 32;
  final secretA2 = 'a2' * 32;
  final secretA3 = 'a3' * 32;
  final secretB1 = 'b1' * 32;
  final secretB2 = 'b2' * 32;

  late ErrorHandler errorHandler;
  late SupabaseBootstrap unconfiguredBootstrap;
  late _SimulatedSupabaseRpcServer server;
  final List<_SimulatedPhoneInstallation> installations = [];

  Future<_SimulatedPhoneInstallation> createInstallation({
    required AuthUser? user,
    required String deviceId,
    required String deviceSecret,
    BackupRpcCaller? customRpcCaller,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final authService = _FakeAuthService(user: user);
    final deviceStorage = BackupDeviceStorage(
      const FlutterSecureStorage(),
      db.backupDao,
      generateDeviceId: () => deviceId,
      generateDeviceSecret: () => deviceSecret,
    );
    await deviceStorage.getOrCreateIdentity();
    final caller = customRpcCaller ?? server.callerForSession(authService);
    final publisher = SupabaseBackupCloudPublisher(
      bootstrap: unconfiguredBootstrap,
      authService: authService,
      deviceStorage: deviceStorage,
      errorHandler: errorHandler,
      rpcCaller: caller,
    );
    final restoreCloud = SupabaseRestoreCloudService(
      bootstrap: unconfiguredBootstrap,
      authService: authService,
      deviceStorage: deviceStorage,
      errorHandler: errorHandler,
      rpcCaller: caller,
    );
    final installation = _SimulatedPhoneInstallation(
      db: db,
      authService: authService,
      deviceStorage: deviceStorage,
      publisher: publisher,
      restoreCloud: restoreCloud,
      deviceId: deviceId,
      deviceSecret: deviceSecret,
    );
    installations.add(installation);
    return installation;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    errorHandler = ErrorHandler(
      AppLogger(output: (_) {}, enableCrashReporting: false),
    );
    unconfiguredBootstrap = SupabaseBootstrap(url: '', anonKey: '');
    server = _SimulatedSupabaseRpcServer();
  });

  tearDown(() async {
    for (final installation in installations) {
      await installation.dispose();
    }
    installations.clear();
  });

  group('Session identity derivation, device proof and input validation', () {
    test('blocks unauthenticated, unverified, unconfigured, blank arguments and mismatched device identity without invoking RPC', () async {
      var rpcCalls = 0;
      final phone = await createInstallation(
        user: const AuthUser(
          id: userA,
          email: 'a@example.com',
          emailVerified: true,
        ),
        deviceId: deviceA2,
        deviceSecret: secretA2,
        customRpcCaller: (_, {required params}) async {
          rpcCalls++;
          return {'status': 'missing_backup'};
        },
      );

      // Blank expectedVersion or blank transfer arguments fail validation locally.
      expect(
        await phone.restoreCloud.readConfirmedSnapshot(expectedVersion: '  '),
        const Left<AppFailure, RestoreCloudSnapshotReadResult>(
          AppFailure(AppErrorCode.validation),
        ),
      );
      expect(
        await phone.restoreCloud.transferBackupAuthority(
          requestId: ' ',
          targetDeviceId: deviceA2,
          expectedVersion: 'v-1',
          expectedActiveDeviceId: deviceA1,
        ),
        const Left<AppFailure, RestoreAuthorityTransferResult>(
          AppFailure(AppErrorCode.validation),
        ),
      );
      expect(
        await phone.restoreCloud.findAuthorityTransfer(
          requestId: 'req-1',
          targetDeviceId: ' ',
        ),
        const Left<AppFailure, RestoreAuthorityTransferred?>(
          AppFailure(AppErrorCode.validation),
        ),
      );

      // Mismatched targetDeviceId vs local persisted installation identity.
      expect(
        await phone.restoreCloud.transferBackupAuthority(
          requestId: 'req-1',
          targetDeviceId: deviceA3,
          expectedVersion: 'v-1',
          expectedActiveDeviceId: deviceA1,
        ),
        const Left<AppFailure, RestoreAuthorityTransferResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );
      expect(
        await phone.restoreCloud.findAuthorityTransfer(
          requestId: 'req-1',
          targetDeviceId: deviceA3,
        ),
        const Left<AppFailure, RestoreAuthorityTransferred?>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      // Signed out session.
      phone.authService.user = null;
      expect(
        await phone.restoreCloud.readConfirmedSnapshot(),
        const Left<AppFailure, RestoreCloudSnapshotReadResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );
      expect(
        await phone.restoreCloud.transferBackupAuthority(
          requestId: 'req-1',
          targetDeviceId: deviceA2,
          expectedVersion: 'v-1',
          expectedActiveDeviceId: deviceA1,
        ),
        const Left<AppFailure, RestoreAuthorityTransferResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      // Unverified email session.
      phone.authService.user = const AuthUser(
        id: userA,
        email: 'a@example.com',
        emailVerified: false,
      );
      expect(
        await phone.restoreCloud.readConfirmedSnapshot(),
        const Left<AppFailure, RestoreCloudSnapshotReadResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      // Unconfigured Supabase client without custom rpcCaller.
      final unconfiguredService = SupabaseRestoreCloudService(
        bootstrap: unconfiguredBootstrap,
        authService: _FakeAuthService(
          user: const AuthUser(
            id: userA,
            email: 'a@example.com',
            emailVerified: true,
          ),
        ),
        deviceStorage: phone.deviceStorage,
        errorHandler: errorHandler,
      );
      expect(
        await unconfiguredService.readConfirmedSnapshot(),
        const Left<AppFailure, RestoreCloudSnapshotReadResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      expect(rpcCalls, 0);
    });

    test(
      'maps network, auth, validation, and malformed snapshot counts safely',
      () async {
        final phone = await createInstallation(
          user: const AuthUser(
            id: userA,
            email: 'a@example.com',
            emailVerified: true,
          ),
          deviceId: deviceA2,
          deviceSecret: secretA2,
        );

        SupabaseRestoreCloudService serviceWith(
          Future<Object?> Function() response,
        ) => SupabaseRestoreCloudService(
          bootstrap: unconfiguredBootstrap,
          authService: phone.authService,
          deviceStorage: phone.deviceStorage,
          errorHandler: errorHandler,
          rpcCaller: (_, {required params}) => response(),
        );

        expect(
          await serviceWith(
            () => Future.error(const SocketException('offline')),
          ).readConfirmedSnapshot(),
          const Left<AppFailure, RestoreCloudSnapshotReadResult>(
            AppFailure(AppErrorCode.network),
          ),
        );
        expect(
          await serviceWith(() => Future.error(TimeoutException('timeout')))
              .transferBackupAuthority(
                requestId: 'req-1',
                targetDeviceId: deviceA2,
                expectedVersion: 'v-1',
                expectedActiveDeviceId: deviceA1,
              ),
          const Left<AppFailure, RestoreAuthorityTransferResult>(
            AppFailure(AppErrorCode.network),
          ),
        );
        expect(
          await serviceWith(
            () => Future.error(
              const sb.PostgrestException(message: 'denied', code: '42501'),
            ),
          ).readConfirmedSnapshot(),
          const Left<AppFailure, RestoreCloudSnapshotReadResult>(
            AppFailure(AppErrorCode.auth),
          ),
        );
        expect(
          await serviceWith(
            () => Future.error(
              const sb.PostgrestException(message: 'bad arg', code: '22023'),
            ),
          ).transferBackupAuthority(
            requestId: 'req-1',
            targetDeviceId: deviceA2,
            expectedVersion: 'v-1',
            expectedActiveDeviceId: deviceA1,
          ),
          const Left<AppFailure, RestoreAuthorityTransferResult>(
            AppFailure(AppErrorCode.validation),
          ),
        );

        // Tampered response claiming customer_count = 2 when only 0 rows are returned.
        expect(
          await serviceWith(
            () async => {
              'status': 'ready',
              'version': 'v-1',
              'active_device_id': deviceA1,
              'confirmed_at': '2026-11-25T10:00:00Z',
              'customer_count': 2,
              'deleted_customer_count': 0,
              'transaction_count': 0,
              'deleted_transaction_count': 0,
              'audit_log_count': 0,
              'customers': const <Object?>[],
              'transactions': const <Object?>[],
              'audit_logs': const <Object?>[],
            },
          ).readConfirmedSnapshot(),
          const Left<AppFailure, RestoreCloudSnapshotReadResult>(
            AppFailure(AppErrorCode.unexpected),
          ),
        );
      },
    );
  });

  group('Multi-batch cumulative snapshot, zero-row snapshot vs missing backup, and two-account isolation', () {
    test('distinguishes missing backup from zero-row confirmed snapshot and reads cumulative multi-batch ledger with two-account isolation', () async {
      const authUserA = AuthUser(
        id: userA,
        email: 'a@example.com',
        emailVerified: true,
      );
      const authUserB = AuthUser(
        id: userB,
        email: 'b@example.com',
        emailVerified: true,
      );

      final phoneA1 = await createInstallation(
        user: authUserA,
        deviceId: deviceA1,
        deviceSecret: secretA1,
      );
      final phoneA2 = await createInstallation(
        user: authUserA,
        deviceId: deviceA2,
        deviceSecret: secretA2,
      );
      final phoneB1 = await createInstallation(
        user: authUserB,
        deviceId: deviceB1,
        deviceSecret: secretB1,
      );

      // 1. Before any backup exists, readConfirmedSnapshot returns RestoreCloudSnapshotMissing.
      expect(
        await phoneA2.restoreCloud.readConfirmedSnapshot(),
        const Right<AppFailure, RestoreCloudSnapshotReadResult>(
          RestoreCloudSnapshotMissing(),
        ),
      );

      // 2. When a confirmed snapshot has zero rows, it returns RestoreCloudSnapshotFound with hasZeroRows == true.
      server.seedZeroRowConfirmedAccount(
        userId: userB,
        activeDeviceId: deviceB1,
        deviceSecret: secretB1,
        confirmedAt: DateTime.utc(2026, 11, 25, 8),
      );
      final zeroRowResult = (await phoneB1.restoreCloud.readConfirmedSnapshot())
          .getOrElse((_) => throw StateError('failed'));
      expect(zeroRowResult, isA<RestoreCloudSnapshotFound>());
      final zeroSnapshot =
          (zeroRowResult as RestoreCloudSnapshotFound).snapshot;
      expect(zeroSnapshot.preview.version, 'v-1');
      expect(zeroSnapshot.preview.hasZeroRows, isTrue);
      expect(zeroSnapshot.customers, isEmpty);
      expect(zeroSnapshot.transactions, isEmpty);
      expect(zeroSnapshot.auditLogs, isEmpty);

      // 3. Phone A1 publishes Batch 1 (2 customers, 2 transactions) and Batch 2
      //    (1 customer edited, 1 customer added, 1 transaction edited + audit,
      //    1 transaction soft-deleted + audit).
      final t0 = DateTime.utc(2026, 11, 25, 9);
      final t1 = DateTime.utc(2026, 11, 25, 9, 15);
      final cust1 = BackupCustomerRecord(
        id: 'cust-a1',
        name: 'Emad Taha',
        phone: '01001111111',
        notes: 'from batch 1 only',
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      );
      final cust2Rev1 = BackupCustomerRecord(
        id: 'cust-a2',
        name: 'Sameh',
        phone: '01002222222',
        notes: 'initial',
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      );
      final tx1Rev1 = BackupTransactionRecord(
        id: 'tx-a1',
        customerId: 'cust-a1',
        type: TransactionType.credit,
        amountPiasters: 10000,
        note: 'flour',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      );
      final tx2Rev1 = BackupTransactionRecord(
        id: 'tx-a2',
        customerId: 'cust-a2',
        type: TransactionType.payment,
        amountPiasters: 4000,
        note: 'cash',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      );

      final batch1Res = await phoneA1.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-a1',
          ownerUserId: userA,
          deviceId: deviceA1,
          capturedAt: t0,
          customers: [cust1, cust2Rev1],
          transactions: [tx1Rev1, tx2Rev1],
          auditLogs: const [],
        ),
      );
      expect(batch1Res.isRight(), isTrue);

      final cust2Rev2 = BackupCustomerRecord(
        id: 'cust-a2',
        name: 'Sameh Grocer',
        phone: '01002222222',
        notes: 'updated in batch 2',
        createdAt: t0,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 2,
      );
      final cust3Deleted = BackupCustomerRecord(
        id: 'cust-a3',
        name: 'Closed Account',
        phone: null,
        notes: null,
        createdAt: t0,
        updatedAt: t1,
        deletedAt: t1,
        localRevision: 2,
      );
      final tx1Rev2 = BackupTransactionRecord(
        id: 'tx-a1',
        customerId: 'cust-a1',
        type: TransactionType.credit,
        amountPiasters: 17500,
        note: 'flour + oil',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 2,
      );
      final tx2Rev2Deleted = BackupTransactionRecord(
        id: 'tx-a2',
        customerId: 'cust-a2',
        type: TransactionType.payment,
        amountPiasters: 4000,
        note: 'cash',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t1,
        deletedAt: t1,
        localRevision: 2,
      );
      final auditEdit = BackupAuditLogRecord(
        id: 'audit-a1',
        transactionId: 'tx-a1',
        action: BackupAuditAction.edit,
        previousType: TransactionType.credit,
        previousAmountPiasters: 10000,
        previousNote: 'flour',
        previousTransactionDate: t0,
        createdAt: t1,
        localRevision: 1,
      );
      final auditDelete = BackupAuditLogRecord(
        id: 'audit-a2',
        transactionId: 'tx-a2',
        action: BackupAuditAction.delete,
        previousType: TransactionType.payment,
        previousAmountPiasters: 4000,
        previousNote: 'cash',
        previousTransactionDate: t0,
        createdAt: t1,
        localRevision: 1,
      );

      final batch2Res = await phoneA1.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-a2',
          ownerUserId: userA,
          deviceId: deviceA1,
          capturedAt: t1,
          customers: [cust2Rev2, cust3Deleted],
          transactions: [tx1Rev2, tx2Rev2Deleted],
          auditLogs: [auditEdit, auditDelete],
        ),
      );
      expect(batch2Res.isRight(), isTrue);

      // Phone B1 publishes an independent batch for Account B.
      final custB1 = BackupCustomerRecord(
        id: 'cust-b1',
        name: 'Account B Customer',
        phone: '01110000000',
        notes: null,
        createdAt: t1,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 1,
      );
      await phoneB1.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-b1',
          ownerUserId: userB,
          deviceId: deviceB1,
          capturedAt: t1,
          customers: [custB1],
          transactions: const [],
          auditLogs: const [],
        ),
      );

      // 4. Phone A2 reads the cumulative confirmed snapshot for Account A at v-2.
      final readA = (await phoneA2.restoreCloud.readConfirmedSnapshot(
        expectedVersion: 'v-2',
      )).getOrElse((_) => throw StateError('failed'));
      expect(readA, isA<RestoreCloudSnapshotFound>());
      final snapshotA = (readA as RestoreCloudSnapshotFound).snapshot;
      expect(snapshotA.preview.version, 'v-2');
      expect(snapshotA.preview.ownerUserId, userA);
      expect(snapshotA.preview.activeDeviceId, deviceA1);
      expect(snapshotA.preview.customerCount, 2);
      expect(snapshotA.preview.deletedCustomerCount, 1);
      expect(snapshotA.preview.transactionCount, 1);
      expect(snapshotA.preview.deletedTransactionCount, 1);
      expect(snapshotA.preview.auditLogCount, 2);
      expect(snapshotA.customers, [cust1, cust2Rev2, cust3Deleted]);
      expect(snapshotA.transactions, [tx1Rev2, tx2Rev2Deleted]);
      expect(snapshotA.auditLogs, [auditEdit, auditDelete]);

      // 5. Phone B1 reads Account B's snapshot and sees zero Account A rows.
      final readB = (await phoneB1.restoreCloud.readConfirmedSnapshot())
          .getOrElse((_) => throw StateError('failed'));
      final snapshotB = (readB as RestoreCloudSnapshotFound).snapshot;
      expect(snapshotB.preview.ownerUserId, userB);
      expect(snapshotB.preview.activeDeviceId, deviceB1);
      expect(snapshotB.customers, [custB1]);
      expect(snapshotB.transactions, isEmpty);
      expect(snapshotB.auditLogs, isEmpty);
    });
  });

  group('Concurrent publication, competing takeovers, retries after lost responses and former-device rejection', () {
    test('serializes concurrent publication and competing takeovers, recovers retries after lost responses, and rejects former device credentials', () async {
      const authUserA = AuthUser(
        id: userA,
        email: 'a@example.com',
        emailVerified: true,
      );
      const authUserB = AuthUser(
        id: userB,
        email: 'b@example.com',
        emailVerified: true,
      );

      final phoneA1 = await createInstallation(
        user: authUserA,
        deviceId: deviceA1,
        deviceSecret: secretA1,
      );
      final phoneA2 = await createInstallation(
        user: authUserA,
        deviceId: deviceA2,
        deviceSecret: secretA2,
      );
      final phoneA3 = await createInstallation(
        user: authUserA,
        deviceId: deviceA3,
        deviceSecret: secretA3,
      );
      final phoneB2 = await createInstallation(
        user: authUserB,
        deviceId: deviceB2,
        deviceSecret: secretB2,
      );

      final ts = DateTime.utc(2026, 11, 25, 10);
      final baseCustomer = BackupCustomerRecord(
        id: 'cust-a1',
        name: 'Initial A1',
        phone: '01001112222',
        notes: null,
        createdAt: ts,
        updatedAt: ts,
        deletedAt: null,
        localRevision: 1,
      );

      // Initial batch v-1 from Phone A1.
      await phoneA1.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-1',
          ownerUserId: userA,
          deviceId: deviceA1,
          capturedAt: ts,
          customers: [baseCustomer],
          transactions: const [],
          auditLogs: const [],
        ),
      );

      // 1. Concurrent publication vs takeover:
      //    Phone A2 previews v-1, then Phone A1 starts publishing batch-2 (v-2)
      //    concurrently while Phone A2 requests takeover expecting v-1.
      final publishEntered = Completer<void>();
      final releasePublish = Completer<void>();
      server.onRpcEntered = (fn, _) async {
        if (fn == SupabaseBackupCloudPublisher.publishBatchRpc &&
            !publishEntered.isCompleted) {
          publishEntered.complete();
          await releasePublish.future;
        }
      };

      final concurrentPublishFuture = phoneA1.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-2',
          ownerUserId: userA,
          deviceId: deviceA1,
          capturedAt: ts.add(const Duration(minutes: 1)),
          customers: [
            BackupCustomerRecord(
              id: 'cust-a1',
              name: 'Edited in Batch 2',
              phone: '01001112222',
              notes: null,
              createdAt: ts,
              updatedAt: ts.add(const Duration(minutes: 1)),
              deletedAt: null,
              localRevision: 2,
            ),
          ],
          transactions: const [],
          auditLogs: const [],
        ),
      );
      await publishEntered.future;

      // Queue takeover expecting stale v-1 while batch-2 holds the server lock.
      final staleTakeoverFuture = phoneA2.restoreCloud.transferBackupAuthority(
        requestId: 'req-stale-v1',
        targetDeviceId: deviceA2,
        expectedVersion: 'v-1',
        expectedActiveDeviceId: deviceA1,
      );

      releasePublish.complete();
      server.onRpcEntered = null;

      final publishOutcome = (await concurrentPublishFuture).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(publishOutcome, isA<BackupPublicationConfirmed>());

      final staleTakeoverOutcome = (await staleTakeoverFuture).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(
        staleTakeoverOutcome,
        isA<RestoreAuthorityPreconditionFailed>()
            .having(
              (r) => r.reason,
              'reason',
              RestorePreconditionFailureReason.versionChanged,
            )
            .having((r) => r.currentVersion, 'currentVersion', 'v-2')
            .having((r) => r.activeDeviceId, 'activeDeviceId', deviceA1),
      );

      // Also verify readConfirmedSnapshot with expectedVersion: 'v-1' detects version change.
      final staleRead = (await phoneA2.restoreCloud.readConfirmedSnapshot(
        expectedVersion: 'v-1',
      )).getOrElse((_) => throw StateError('failed'));
      expect(
        staleRead,
        isA<RestoreCloudSnapshotVersionChanged>().having(
          (r) => r.preview.version,
          'version',
          'v-2',
        ),
      );

      // 2. Competing takeovers (Phone A2 and Phone A3 both target v-2, deviceA1):
      //    Phone A2 acquires server lock first; Phone A3 queues behind it.
      final takeoverEntered = Completer<void>();
      final releaseTakeover = Completer<void>();
      server.onRpcEntered = (fn, params) async {
        if (fn == SupabaseRestoreCloudService.transferBackupAuthorityRpc &&
            params['p_request_id'] == 'req-win-a2' &&
            !takeoverEntered.isCompleted) {
          takeoverEntered.complete();
          await releaseTakeover.future;
        }
      };

      final winnerFuture = phoneA2.restoreCloud.transferBackupAuthority(
        requestId: 'req-win-a2',
        targetDeviceId: deviceA2,
        expectedVersion: 'v-2',
        expectedActiveDeviceId: deviceA1,
      );
      await takeoverEntered.future;

      final loserFuture = phoneA3.restoreCloud.transferBackupAuthority(
        requestId: 'req-lose-a3',
        targetDeviceId: deviceA3,
        expectedVersion: 'v-2',
        expectedActiveDeviceId: deviceA1,
      );

      releaseTakeover.complete();
      server.onRpcEntered = null;

      final winnerOutcome = (await winnerFuture).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(
        winnerOutcome,
        isA<RestoreAuthorityTransferred>()
            .having((r) => r.requestId, 'requestId', 'req-win-a2')
            .having((r) => r.version, 'version', 'v-2')
            .having((r) => r.activeDeviceId, 'activeDeviceId', deviceA2),
      );

      final loserOutcome = (await loserFuture).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(
        loserOutcome,
        isA<RestoreAuthorityPreconditionFailed>()
            .having(
              (r) => r.reason,
              'reason',
              RestorePreconditionFailureReason.activeDeviceChanged,
            )
            .having((r) => r.currentVersion, 'currentVersion', 'v-2')
            .having((r) => r.activeDeviceId, 'activeDeviceId', deviceA2),
      );

      // 3. Retry after lost response: Phone A2 replays 'req-win-a2' with
      //    expectedActiveDeviceId = deviceA1 (even though deviceA2 is now active!)
      //    and queries findAuthorityTransfer. Both recover the exact original outcome.
      final replayedOutcome =
          (await phoneA2.restoreCloud.transferBackupAuthority(
            requestId: 'req-win-a2',
            targetDeviceId: deviceA2,
            expectedVersion: 'v-2',
            expectedActiveDeviceId: deviceA1,
          )).getOrElse((_) => throw StateError('failed'));
      expect(replayedOutcome, winnerOutcome);

      final lookedUpOutcome = (await phoneA2.restoreCloud.findAuthorityTransfer(
        requestId: 'req-win-a2',
        targetDeviceId: deviceA2,
      )).getOrElse((_) => throw StateError('failed'));
      expect(lookedUpOutcome, winnerOutcome);

      // Another account (Phone B2) or another device (Phone A3) cannot look up or replay 'req-win-a2'.
      expect(
        await phoneB2.restoreCloud.findAuthorityTransfer(
          requestId: 'req-win-a2',
          targetDeviceId: deviceB2,
        ),
        const Right<AppFailure, RestoreAuthorityTransferred?>(null),
      );
      expect(
        await phoneA3.restoreCloud.findAuthorityTransfer(
          requestId: 'req-win-a2',
          targetDeviceId: deviceA3,
        ),
        const Left<AppFailure, RestoreAuthorityTransferred?>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      // 4. Rejection of the former device's credentials (Phone A1):
      //    Both publishBatch and findBatchConfirmation on Phone A1 now return inactive_device.
      expect(
        await phoneA1.publisher.publishBatch(
          BackupBatch(
            batchId: 'batch-rejected-a1',
            ownerUserId: userA,
            deviceId: deviceA1,
            capturedAt: ts.add(const Duration(minutes: 5)),
            customers: [
              BackupCustomerRecord(
                id: 'cust-a1',
                name: 'Rejected From Former Phone',
                phone: '01001112222',
                notes: null,
                createdAt: ts,
                updatedAt: ts.add(const Duration(minutes: 5)),
                deletedAt: null,
                localRevision: 99,
              ),
            ],
            transactions: const [],
            auditLogs: const [],
          ),
        ),
        const Right<AppFailure, BackupPublicationResult>(
          BackupPublicationInactiveDevice(),
        ),
      );
      expect(
        await phoneA1.publisher.findBatchConfirmation(
          batchId: 'batch-1',
          ownerUserId: userA,
          deviceId: deviceA1,
        ),
        const Right<AppFailure, BackupPublicationResult?>(
          BackupPublicationInactiveDevice(),
        ),
      );

      // 5. The new active device (Phone A2) publishes Batch 3 cleanly under its new authority.
      final newPhoneBatchRes = await phoneA2.publisher.publishBatch(
        BackupBatch(
          batchId: 'batch-3-from-a2',
          ownerUserId: userA,
          deviceId: deviceA2,
          capturedAt: ts.add(const Duration(minutes: 6)),
          customers: [
            BackupCustomerRecord(
              id: 'cust-a1',
              name: 'Published By New Active Phone A2',
              phone: '01001112222',
              notes: null,
              createdAt: ts,
              updatedAt: ts.add(const Duration(minutes: 6)),
              deletedAt: null,
              localRevision: 3,
            ),
          ],
          transactions: const [],
          auditLogs: const [],
        ),
      );
      expect(
        newPhoneBatchRes.getOrElse((_) => throw StateError('failed')),
        isA<BackupPublicationConfirmed>(),
      );

      final postA2Snapshot =
          ((await phoneA2.restoreCloud.readConfirmedSnapshot()).getOrElse(
            (_) => throw StateError('failed'),
          ) as RestoreCloudSnapshotFound).snapshot;
      expect(postA2Snapshot.preview.version, 'v-3');
      expect(postA2Snapshot.preview.activeDeviceId, deviceA2);
      expect(
        postA2Snapshot.customers.single.name,
        'Published By New Active Phone A2',
      );
    });
  });

  group('Phase 13 forward migration SQL invariants', () {
    test('forward migration preserves unqualified conditional expressions and locks down authority transfer credentials', () {
      final sqlFile = File(
        'supabase/migrations/20261125000000_phase_13_cloud_restore_and_transfer.sql',
      );
      expect(sqlFile.existsSync(), isTrue);
      final sql = sqlFile.readAsStringSync().toLowerCase();

      expect(sql, isNot(contains('pg_catalog.coalesce')));
      expect(sql, isNot(contains('pg_catalog.greatest')));
      expect(
        sql,
        contains(
          'create table if not exists public.backup_authority_transfers',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.backup_authority_transfers from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        isNot(
          contains('grant select on table public.backup_authority_transfers'),
        ),
      );
      expect(
        sql,
        contains(
          'create or replace function public.read_confirmed_backup_snapshot',
        ),
      );
      expect(
        sql,
        contains('create or replace function public.transfer_backup_authority'),
      );
      expect(
        sql,
        contains(
          'create or replace function public.find_backup_authority_transfer',
        ),
      );
    });
  });
}
