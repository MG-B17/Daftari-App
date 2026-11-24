import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/data/services/supabase_bootstrap.dart';
import '../../domain/entities/backup_batch.dart';
import '../../domain/entities/backup_run_result.dart';
import '../../domain/repositories/backup_cloud_publisher.dart';
import '../models/backup_batch_codec.dart';
import '../services/backup_device_storage.dart';

typedef BackupRpcCaller = Future<Object?> Function(
  String functionName, {
  required Map<String, dynamic> params,
});

/// Supabase RPC implementation of [BackupCloudPublisher].
///
/// Delegates atomic publication and confirmation lookup to
/// `publish_backup_batch` and `find_backup_batch_confirmation`, authenticating
/// both the linked verified session and this installation's local-only device
/// credential before any network request.
class SupabaseBackupCloudPublisher implements BackupCloudPublisher {
  SupabaseBackupCloudPublisher({
    required this._bootstrap,
    required this._authService,
    required this._deviceStorage,
    required this._errorHandler,
    this._rpcCaller,
  });

  static const findBatchConfirmationRpc = 'find_backup_batch_confirmation';
  static const publishBatchRpc = 'publish_backup_batch';

  final SupabaseBootstrap _bootstrap;
  final AuthService _authService;
  final BackupDeviceStorage _deviceStorage;
  final ErrorHandler _errorHandler;
  final BackupRpcCaller? _rpcCaller;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) => _guard(() async {
    final trimmedBatchId = batchId.trim();
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedDeviceId = deviceId.trim();
    if (trimmedBatchId.isEmpty ||
        trimmedOwnerId.isEmpty ||
        trimmedDeviceId.isEmpty) {
      throw const ValidationException();
    }

    _requireMatchingVerifiedSession(trimmedOwnerId);
    final identity = await _requireMatchingDeviceIdentity(trimmedDeviceId);

    final raw = await _invokeRpc(
      findBatchConfirmationRpc,
      params: BackupBatchCodec.toFindConfirmationRpcParams(
        batchId: trimmedBatchId,
        deviceId: identity.deviceId,
        deviceSecret: identity.deviceSecret,
      ),
    );
    return BackupBatchCodec.parseFindConfirmationResponse(
      raw,
      expectedBatchId: trimmedBatchId,
    );
  });

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) => _guard(() async {
    if (batch.isEmpty ||
        batch.batchId.trim().isEmpty ||
        batch.ownerUserId.trim().isEmpty ||
        batch.deviceId.trim().isEmpty) {
      throw const ValidationException();
    }

    _requireMatchingVerifiedSession(batch.ownerUserId);
    final identity = await _requireMatchingDeviceIdentity(batch.deviceId);

    final raw = await _invokeRpc(
      publishBatchRpc,
      params: BackupBatchCodec.toPublishRpcParams(
        batch,
        deviceSecret: identity.deviceSecret,
      ),
    );
    return BackupBatchCodec.parsePublishResponse(
      raw,
      expectedBatchId: batch.batchId,
    );
  });

  void _requireMatchingVerifiedSession(String expectedOwnerUserId) {
    if (_rpcCaller == null && !_bootstrap.isConfigured) {
      throw const AuthException();
    }
    final user = _authService.currentUser;
    if (user == null || !user.emailVerified || user.id != expectedOwnerUserId) {
      throw const AuthException();
    }
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
