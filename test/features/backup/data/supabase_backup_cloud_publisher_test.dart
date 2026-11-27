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
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = '11111111-1111-4111-8111-111111111111';
  const userB = '22222222-2222-4222-8222-222222222222';
  const deviceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const deviceB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  final secretA = 'a'.padRight(64, '1');

  late ErrorHandler errorHandler;
  late SupabaseBootstrap unconfiguredBootstrap;
  late AppDatabase db;
  late BackupDeviceStorage deviceStorage;

  BackupBatch sampleBatch({
    String batchId = 'batch-1',
    String ownerUserId = userA,
    String deviceId = deviceA,
    String customerId = 'cust-1',
    String transactionId = 'tx-1',
    String auditId = 'audit-1',
  }) {
    final ts = DateTime.utc(2026, 11, 24, 9);
    return BackupBatch(
      batchId: batchId,
      ownerUserId: ownerUserId,
      deviceId: deviceId,
      capturedAt: ts,
      customers: [
        BackupCustomerRecord(
          id: customerId,
          name: 'Ahmed',
          phone: '01000000000',
          notes: 'regular',
          createdAt: ts,
          updatedAt: ts,
          deletedAt: null,
          localRevision: 1,
        ),
      ],
      transactions: [
        BackupTransactionRecord(
          id: transactionId,
          customerId: customerId,
          type: TransactionType.credit,
          amountPiasters: 15000,
          note: 'edited',
          transactionDate: ts,
          createdAt: ts,
          updatedAt: ts,
          deletedAt: null,
          localRevision: 2,
        ),
      ],
      auditLogs: [
        BackupAuditLogRecord(
          id: auditId,
          transactionId: transactionId,
          action: BackupAuditAction.edit,
          previousType: TransactionType.credit,
          previousAmountPiasters: 10000,
          previousNote: 'initial',
          previousTransactionDate: ts,
          createdAt: ts,
          localRevision: 1,
        ),
      ],
    );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    errorHandler = ErrorHandler(AppLogger(output: (_) {}));
    unconfiguredBootstrap = SupabaseBootstrap(url: '', anonKey: '');
    db = AppDatabase(NativeDatabase.memory());
    deviceStorage = BackupDeviceStorage(
      const FlutterSecureStorage(),
      db.backupDao,
      generateDeviceId: () => deviceA,
      generateDeviceSecret: () => secretA,
    );
    await deviceStorage.getOrCreateIdentity();
  });

  tearDown(() => db.close());

  group('Session, installation credential and payload encoding', () {
    test('serializes full batch and installation secret to publish_backup_batch and find_backup_batch_confirmation', () async {
      final capturedCalls = <({String fn, Map<String, dynamic> params})>[];
      final confirmedAt = DateTime.utc(2026, 11, 24, 10, 0, 5, 500);

      final publisher = SupabaseBackupCloudPublisher(
        bootstrap: unconfiguredBootstrap,
        authService: _FakeAuthService(
          user: const AuthUser(
            id: userA,
            email: 'a@example.com',
            emailVerified: true,
          ),
        ),
        deviceStorage: deviceStorage,
        errorHandler: errorHandler,
        rpcCaller: (fn, {required params}) async {
          capturedCalls.add((fn: fn, params: params));
          return {
            'status': 'confirmed',
            'batch_id': 'batch-1',
            'confirmed_at': confirmedAt.toIso8601String(),
          };
        },
      );

      final publishResult = await publisher.publishBatch(sampleBatch());
      final lookupResult = await publisher.findBatchConfirmation(
        batchId: 'batch-1',
        ownerUserId: userA,
        deviceId: deviceA,
      );

      expect(capturedCalls, hasLength(2));
      expect(capturedCalls[0].fn, SupabaseBackupCloudPublisher.publishBatchRpc);
      expect(capturedCalls[0].params['p_batch_id'], 'batch-1');
      expect(capturedCalls[0].params['p_device_id'], deviceA);
      expect(capturedCalls[0].params['p_device_secret'], secretA);
      expect((capturedCalls[0].params['p_customers'] as List), hasLength(1));
      expect((capturedCalls[0].params['p_transactions'] as List), hasLength(1));
      expect((capturedCalls[0].params['p_audit_logs'] as List), hasLength(1));

      expect(
        capturedCalls[1].fn,
        SupabaseBackupCloudPublisher.findBatchConfirmationRpc,
      );
      expect(capturedCalls[1].params['p_device_id'], deviceA);
      expect(capturedCalls[1].params['p_device_secret'], secretA);

      final expectedConfirmed = BackupPublicationConfirmed(
        batchId: 'batch-1',
        confirmedAt: confirmedAt,
      );
      expect(
        publishResult,
        Right<AppFailure, BackupPublicationResult>(expectedConfirmed),
      );
      expect(
        lookupResult,
        Right<AppFailure, BackupPublicationResult?>(expectedConfirmed),
      );
    });

    test('blocks empty batch, unconfigured client, invalid session and mismatched installation identity without calling RPC', () async {
      var rpcCalls = 0;
      final authService = _FakeAuthService(
        user: const AuthUser(
          id: userA,
          email: 'a@example.com',
          emailVerified: true,
        ),
      );
      final publisher = SupabaseBackupCloudPublisher(
        bootstrap: unconfiguredBootstrap,
        authService: authService,
        deviceStorage: deviceStorage,
        errorHandler: errorHandler,
        rpcCaller: (_, {required params}) async {
          rpcCalls++;
          return {'status': 'not_found'};
        },
      );

      final emptyBatch = BackupBatch(
        batchId: 'b-empty',
        ownerUserId: userA,
        deviceId: deviceA,
        capturedAt: DateTime.utc(2026, 11, 24),
        customers: const [],
        transactions: const [],
        auditLogs: const [],
      );
      expect(
        await publisher.publishBatch(emptyBatch),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.validation),
        ),
      );

      // Mismatched batch deviceId vs persisted installation identity.
      expect(
        await publisher.publishBatch(sampleBatch(deviceId: deviceB)),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );
      expect(
        await publisher.findBatchConfirmation(
          batchId: 'batch-1',
          ownerUserId: userA,
          deviceId: deviceB,
        ),
        const Left<AppFailure, BackupPublicationResult?>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      authService.user = null;
      expect(
        await publisher.publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      authService.user = const AuthUser(
        id: userA,
        email: 'a@example.com',
        emailVerified: false,
      );
      expect(
        await publisher.publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      authService.user = const AuthUser(
        id: userB,
        email: 'b@example.com',
        emailVerified: true,
      );
      expect(
        await publisher.publishBatch(sampleBatch(ownerUserId: userA)),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      final unconfiguredPublisher = SupabaseBackupCloudPublisher(
        bootstrap: unconfiguredBootstrap,
        authService: _FakeAuthService(
          user: const AuthUser(
            id: userA,
            email: 'a@example.com',
            emailVerified: true,
          ),
        ),
        deviceStorage: deviceStorage,
        errorHandler: errorHandler,
      );
      expect(
        await unconfiguredPublisher.publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );

      expect(rpcCalls, 0);
    });

    test('maps inactive_device, not_found, network, auth, validation and malformed server responses safely', () async {
      final authService = _FakeAuthService(
        user: const AuthUser(
          id: userA,
          email: 'a@example.com',
          emailVerified: true,
        ),
      );

      SupabaseBackupCloudPublisher publisherWith(
        Future<Object?> Function() response,
      ) => SupabaseBackupCloudPublisher(
        bootstrap: unconfiguredBootstrap,
        authService: authService,
        deviceStorage: deviceStorage,
        errorHandler: errorHandler,
        rpcCaller: (_, {required params}) => response(),
      );

      expect(
        await publisherWith(() async => {'status': 'inactive_device'})
            .publishBatch(sampleBatch()),
        const Right<AppFailure, BackupPublicationResult>(
          BackupPublicationInactiveDevice(),
        ),
      );
      expect(
        await publisherWith(() async => {'status': 'not_found'})
            .findBatchConfirmation(
              batchId: 'batch-1',
              ownerUserId: userA,
              deviceId: deviceA,
            ),
        const Right<AppFailure, BackupPublicationResult?>(null),
      );
      expect(
        await publisherWith(
          () => Future.error(const SocketException('offline')),
        ).publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.network),
        ),
      );
      expect(
        await publisherWith(() => Future.error(TimeoutException('timeout')))
            .publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.network),
        ),
      );
      expect(
        await publisherWith(
          () => Future.error(
            const sb.PostgrestException(message: 'denied', code: '42501'),
          ),
        ).publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.auth),
        ),
      );
      expect(
        await publisherWith(
          () => Future.error(
            const sb.PostgrestException(message: 'fk violation', code: '23503'),
          ),
        ).publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.validation),
        ),
      );
      expect(
        await publisherWith(
          () async => {
            'status': 'confirmed',
            'batch_id': 'wrong-batch-id',
            'confirmed_at': '2026-11-24T10:00:00Z',
          },
        ).publishBatch(sampleBatch()),
        const Left<AppFailure, BackupPublicationResult>(
          AppFailure(AppErrorCode.unexpected),
        ),
      );
    });
  });

  group('Supabase migration SQL invariants', () {
    test('migration uses unqualified conditional expressions and enforces private installation credentials', () {
      final sqlFile = File(
        'supabase/migrations/20261124000000_phase_12_cloud_backup.sql',
      );
      expect(sqlFile.existsSync(), isTrue);
      final sql = sqlFile.readAsStringSync().toLowerCase();

      // P12-09 regression guard: never qualify PostgreSQL conditional expressions.
      expect(sql, isNot(contains('pg_catalog.coalesce')));
      expect(sql, isNot(contains('pg_catalog.greatest')));
      expect(sql, contains('greatest('));
      expect(sql, contains('coalesce(last_confirmed_at, v_now)'));

      // P12-10 regression guard: private device credentials table with zero client grants.
      expect(
        sql,
        contains('create table if not exists public.backup_device_credentials'),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.backup_device_credentials from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        isNot(
          contains('grant select on table public.backup_device_credentials'),
        ),
      );
      expect(sql, contains('pg_catalog.sha256'));
      expect(sql, contains('p_device_secret text'));
    });
  });
}
