import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/database/daos/customer_dao.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/ledger_link_status.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/ledger_owner_storage.dart';
import '../services/supabase_auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(
    this._authService,
    this._ownerStorage,
    this._customerDao,
    this._errorHandler,
  );

  final AuthService _authService;
  final LedgerOwnerStorage _ownerStorage;
  final CustomerDao _customerDao;
  final ErrorHandler _errorHandler;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() {
    late final StreamController<AuthSessionEvent> controller;
    StreamSubscription<AuthSessionEvent>? subscription;
    var pending = Future<void>.value();

    controller = StreamController<AuthSessionEvent>(
      onListen: () {
        subscription = _authService.watchAuthChanges().listen(
          (event) {
            pending = pending.then((_) {
              if (!controller.isClosed) controller.add(event);
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            pending = pending.then((_) async {
              final failure = await _mapError(error);
              if (!controller.isClosed) {
                controller.add(AuthSessionFailure(failure));
              }
            });
          },
          onDone: () {
            pending = pending.then((_) async {
              if (!controller.isClosed) await controller.close();
            });
          },
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Either<AppFailure, AuthUser?>> getCurrentUser() =>
      _guard(_authService.getCurrentUser);

  @override
  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(() async {
    try {
      return await _authService.signInWithPassword(
        email: email,
        password: password,
      );
    } on sb.AuthException catch (error) {
      if (SupabaseAuthService.isEmailNotConfirmedError(error)) {
        return AuthUser(id: '', email: email, emailVerified: false);
      }
      rethrow;
    }
  });

  @override
  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) => _guard(
    () => _authService.signUpWithPassword(
      email: email,
      password: password,
      shopName: shopName,
    ),
  );

  @override
  Future<Either<AppFailure, void>> signOut({String? expectedUserId}) =>
      _guard(() => _authService.signOut(expectedUserId: expectedUserId));

  @override
  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email) =>
      _guard(() => _authService.sendPasswordResetEmail(email));

  @override
  Future<Either<AppFailure, void>> resendVerificationEmail(String email) =>
      _guard(() => _authService.resendVerificationEmail(email));

  @override
  Future<Either<AppFailure, void>> updatePassword(String newPassword) =>
      _guard(() => _authService.updatePassword(newPassword));

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  ) => _guard(() async {
    final ownerId = await _ownerStorage.readOwnerId();
    if (ownerId == null) return LedgerLinkStatus.unlinked;
    if (ownerId == userId) return LedgerLinkStatus.linkedToCurrentUser;
    return LedgerLinkStatus.linkedToOtherUser;
  });

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> linkLedgerToUser(
    String userId,
  ) => _guard(() async {
    final trimmed = userId.trim();
    final committedOwnerId = await _ownerStorage.claimOwnerId(
      trimmed,
      canClaim: () {
        final current = _authService.currentUser;
        return current != null &&
            current.id == trimmed &&
            current.emailVerified;
      },
    );
    if (committedOwnerId == null) throw const AuthException();
    return committedOwnerId == trimmed
        ? LedgerLinkStatus.linkedToCurrentUser
        : LedgerLinkStatus.linkedToOtherUser;
  });

  @override
  Future<Either<AppFailure, bool>> hasLocalLedgerData() =>
      _guard(_customerDao.hasAnyCustomers);

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
        error is TimeoutException) {
      return _errorHandler.handle(const NetworkException());
    }
    if (error is sb.AuthException) {
      return _errorHandler.handle(const AuthException());
    }
    return _errorHandler.handle(error);
  }
}
