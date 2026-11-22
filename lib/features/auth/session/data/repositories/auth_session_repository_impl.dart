import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/ledger_link_status.dart';
import '../../domain/repositories/auth_session_repository.dart';
import '../services/auth_error_mapper.dart';
import '../services/ledger_owner_storage.dart';
import '../services/supabase_auth_service.dart';

class AuthSessionRepositoryImpl implements AuthSessionRepository {
  const AuthSessionRepositoryImpl(
    this._authService,
    this._ownerStorage,
    this._hasLocalLedgerData,
    this._errorMapper,
  );

  final AuthService _authService;
  final LedgerOwnerStorage _ownerStorage;
  final Future<bool> Function() _hasLocalLedgerData;
  final AuthErrorMapper _errorMapper;

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
              final failure = await _errorMapper.mapError(error);
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
      _errorMapper.guard(_authService.getCurrentUser);

  @override
  Future<Either<AppFailure, void>> signOut({String? expectedUserId}) =>
      _errorMapper.guard(
        () => _authService.signOut(expectedUserId: expectedUserId),
      );

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  ) => _errorMapper.guard(() async {
    final ownerId = await _ownerStorage.readOwnerId();
    if (ownerId == null) return LedgerLinkStatus.unlinked;
    if (ownerId == userId) return LedgerLinkStatus.linkedToCurrentUser;
    return LedgerLinkStatus.linkedToOtherUser;
  });

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> linkLedgerToUser(
    String userId,
  ) => _errorMapper.guard(() async {
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
      _errorMapper.guard(_hasLocalLedgerData);
}
