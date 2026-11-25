import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/data/services/supabase_bootstrap.dart';
import '../../../auth/session/domain/entities/auth_user.dart';
import '../../../backup/data/repositories/supabase_backup_cloud_publisher.dart';
import '../../../backup/data/services/backup_device_storage.dart';
import '../../domain/entities/restore_entities.dart';
import '../../domain/repositories/restore_cloud_service.dart';
import '../models/restore_cloud_codec.dart';

/// Supabase RPC implementation of [RestoreCloudService].
///
/// Derives account identity strictly from the authenticated verified session
/// and authenticates the receiving installation's local device credential when
/// requesting or recovering backup authority takeover.
class SupabaseRestoreCloudService implements RestoreCloudService {
  SupabaseRestoreCloudService({
    required this._bootstrap,
    required this._authService,
    required this._deviceStorage,
    required this._errorHandler,
    this._rpcCaller,
  });

  static const readConfirmedSnapshotRpc = 'read_confirmed_backup_snapshot';
  static const transferBackupAuthorityRpc = 'transfer_backup_authority';
  static const findAuthorityTransferRpc = 'find_backup_authority_transfer';

  final SupabaseBootstrap _bootstrap;
  final AuthService _authService;
  final BackupDeviceStorage _deviceStorage;
  final ErrorHandler _errorHandler;
  final BackupRpcCaller? _rpcCaller;

  @override
  Future<Either<AppFailure, RestoreCloudSnapshotReadResult>>
  readConfirmedSnapshot({String? expectedVersion}) => _guard(() async {
    final String? trimmedExpectedVersion;
    if (expectedVersion != null) {
      trimmedExpectedVersion = expectedVersion.trim();
      if (trimmedExpectedVersion.isEmpty) {
        throw const ValidationException();
      }
    } else {
      trimmedExpectedVersion = null;
    }

    final user = _requireVerifiedSessionUser();

    final raw = await _invokeRpc(
      readConfirmedSnapshotRpc,
      params: RestoreCloudCodec.toReadSnapshotRpcParams(
        expectedVersion: trimmedExpectedVersion,
      ),
    );
    return RestoreCloudCodec.parseReadSnapshotResponse(
      raw,
      ownerUserId: user.id,
      expectedVersion: trimmedExpectedVersion,
    );
  });

  @override
  Future<Either<AppFailure, RestoreAuthorityTransferResult>>
  transferBackupAuthority({
    required String requestId,
    required String targetDeviceId,
    required String expectedVersion,
    required String expectedActiveDeviceId,
  }) => _guard(() async {
    final trimmedRequestId = requestId.trim();
    final trimmedTargetDeviceId = targetDeviceId.trim();
    final trimmedExpectedVersion = expectedVersion.trim();
    final trimmedExpectedActiveDeviceId = expectedActiveDeviceId.trim();
    if (trimmedRequestId.isEmpty ||
        trimmedTargetDeviceId.isEmpty ||
        trimmedExpectedVersion.isEmpty ||
        trimmedExpectedActiveDeviceId.isEmpty) {
      throw const ValidationException();
    }

    _requireVerifiedSessionUser();
    final identity = await _requireMatchingDeviceIdentity(
      trimmedTargetDeviceId,
    );

    final raw = await _invokeRpc(
      transferBackupAuthorityRpc,
      params: RestoreCloudCodec.toTransferAuthorityRpcParams(
        requestId: trimmedRequestId,
        targetDeviceId: identity.deviceId,
        targetDeviceSecret: identity.deviceSecret,
        expectedVersion: trimmedExpectedVersion,
        expectedActiveDeviceId: trimmedExpectedActiveDeviceId,
      ),
    );
    return RestoreCloudCodec.parseTransferAuthorityResponse(
      raw,
      expectedRequestId: trimmedRequestId,
      expectedTargetDeviceId: identity.deviceId,
    );
  });

  @override
  Future<Either<AppFailure, RestoreAuthorityTransferred?>>
  findAuthorityTransfer({
    required String requestId,
    required String targetDeviceId,
  }) => _guard(() async {
    final trimmedRequestId = requestId.trim();
    final trimmedTargetDeviceId = targetDeviceId.trim();
    if (trimmedRequestId.isEmpty || trimmedTargetDeviceId.isEmpty) {
      throw const ValidationException();
    }

    _requireVerifiedSessionUser();
    final identity = await _requireMatchingDeviceIdentity(
      trimmedTargetDeviceId,
    );

    final raw = await _invokeRpc(
      findAuthorityTransferRpc,
      params: RestoreCloudCodec.toFindAuthorityTransferRpcParams(
        requestId: trimmedRequestId,
        targetDeviceId: identity.deviceId,
        targetDeviceSecret: identity.deviceSecret,
      ),
    );
    return RestoreCloudCodec.parseFindAuthorityTransferResponse(
      raw,
      expectedRequestId: trimmedRequestId,
      expectedTargetDeviceId: identity.deviceId,
    );
  });

  AuthUser _requireVerifiedSessionUser() {
    if (_rpcCaller == null && !_bootstrap.isConfigured) {
      throw const AuthException();
    }
    final user = _authService.currentUser;
    if (user == null || !user.emailVerified || user.id.trim().isEmpty) {
      throw const AuthException();
    }
    return user;
  }

  Future<BackupDeviceIdentity> _requireMatchingDeviceIdentity(
    String expectedDeviceId,
  ) async {
    final identity = await _deviceStorage.readIdentity();
    if (identity == null || identity.deviceId != expectedDeviceId) {
      throw const AuthException();
    }
    return identity;
  }

  Future<Object?> _invokeRpc(
    String functionName, {
    required Map<String, dynamic> params,
  }) {
    final caller = _rpcCaller;
    if (caller != null) {
      return caller(functionName, params: params);
    }
    final client = _bootstrap.client;
    if (client == null) {
      throw const AuthException();
    }
    return client.rpc<Object?>(functionName, params: params);
  }

  Future<Either<AppFailure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await _mapError(error));
    }
  }

  Future<AppFailure> _mapError(Object error) {
    if (error is AppException) return _errorHandler.handle(error);
    if (error is sb.AuthRetryableFetchException ||
        error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return _errorHandler.handle(const NetworkException());
    }
    if (error is sb.AuthException) {
      return _errorHandler.handle(const AuthException());
    }
    if (error is sb.PostgrestException) {
      return _errorHandler.handle(_mapPostgrestError(error));
    }
    return _errorHandler.handle(error);
  }

  static AppException _mapPostgrestError(sb.PostgrestException error) {
    final code = error.code?.toUpperCase();
    if (code == '42501' || code == 'PGRST301' || code == 'PGRST302') {
      return const AuthException();
    }
    if (code == '22023' ||
        code == '22P02' ||
        code == '23502' ||
        code == '23503' ||
        code == '23514') {
      return const ValidationException();
    }
    return const UnexpectedException();
  }
}
