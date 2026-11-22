import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/confirm_ledger_link_usecase.dart';
import '../../domain/usecases/ledger_link_evaluator.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/update_password_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> implements Listenable {
  AuthCubit(
    this._repository,
    this._signIn,
    this._signUp,
    this._signOut,
    this._confirmLedgerLink,
    this._sendPasswordReset,
    this._updatePassword,
  ) : super(AuthState(isConfigured: _repository.isConfigured));

  final AuthRepository _repository;
  final SignInUseCase _signIn;
  final SignUpUseCase _signUp;
  final SignOutUseCase _signOut;
  final ConfirmLedgerLinkUseCase _confirmLedgerLink;
  final SendPasswordResetUseCase _sendPasswordReset;
  final UpdatePasswordUseCase _updatePassword;

  final ValueNotifier<int> _routing = ValueNotifier<int>(0);
  StreamSubscription<AuthSessionEvent>? _authSubscription;
  Future<void>? _initializing;
  bool _handlingAction = false;

  @override
  void addListener(VoidCallback listener) => _routing.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _routing.removeListener(listener);

  @override
  void emit(AuthState state) {
    final previous = this.state;
    super.emit(state);
    if (previous.passwordRecoveryPending != state.passwordRecoveryPending) {
      _routing.value++;
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    final configured = _repository.isConfigured;

    await _authSubscription?.cancel();
    _authSubscription = _repository.watchAuthChanges().listen(_onAuthEvent);

    if (configured) {
      final currentResult = await _repository.getCurrentUser();
      if (isClosed) return;
      await currentResult.fold(
        (_) async {
          emit(
            state.copyWith(
              initialized: true,
              isConfigured: configured,
              status: AuthStatus.unauthenticated,
              clearUser: true,
            ),
          );
        },
        (user) async {
          if (user == null) {
            emit(
              state.copyWith(
                initialized: true,
                isConfigured: configured,
                status: AuthStatus.unauthenticated,
                clearUser: true,
              ),
            );
            return;
          }
          await _evaluateSessionUser(user, markInitialized: true);
        },
      );
      return;
    }

    if (!isClosed) {
      emit(
        state.copyWith(
          initialized: true,
          isConfigured: configured,
          status: AuthStatus.unauthenticated,
          clearUser: true,
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (!_ensureConfigured() || state.busy) return;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _signIn(email: email, password: password);
      if (isClosed) return;
      result.fold(
        (failure) => _emitFailure(failure),
        (outcome) => _applyOutcome(outcome),
      );
    } finally {
      _handlingAction = false;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {
    if (!_ensureConfigured() || state.busy) return;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _signUp(
        email: email,
        password: password,
        shopName: shopName,
      );
      if (isClosed) return;
      result.fold(
        (failure) => _emitFailure(failure),
        (outcome) => _applyOutcome(outcome),
      );
    } finally {
      _handlingAction = false;
    }
  }

  Future<void> confirmLedgerLink({required bool confirmed}) async {
    final pendingUser = state.user;
    if (pendingUser == null || state.busy) return;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _confirmLedgerLink(
        user: pendingUser,
        confirmed: confirmed,
      );
      if (isClosed) return;
      result.fold(
        (failure) => emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            pendingHasLocalData: false,
            feedback: _mapFailure(failure),
            feedbackId: state.feedbackId + 1,
          ),
        ),
        (outcome) {
          if (outcome == null) {
            emit(
              state.copyWith(
                busy: false,
                status: AuthStatus.unauthenticated,
                clearUser: true,
                pendingHasLocalData: false,
              ),
            );
            return;
          }
          _applyOutcome(outcome, linkedJustNow: outcome is AuthSignedIn);
        },
      );
    } finally {
      _handlingAction = false;
    }
  }

  Future<void> signOut() async {
    if (state.busy) return;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _signOut();
      if (isClosed) return;
      result.fold(
        (failure) => _emitFailure(failure),
        (_) => emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            clearPendingEmail: true,
            pendingHasLocalData: false,
            passwordRecoveryPending: false,
            feedback: AuthFeedback.signedOut,
            feedbackId: state.feedbackId + 1,
          ),
        ),
      );
    } finally {
      _handlingAction = false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    if (!_ensureConfigured() || state.busy) return false;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = await _sendPasswordReset(email);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _emitFailure(failure);
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            busy: false,
            pendingEmail: email.trim(),
            feedback: AuthFeedback.passwordResetSent,
            feedbackId: state.feedbackId + 1,
          ),
        );
        return true;
      },
    );
  }

  Future<void> resendVerificationEmail(String email) async {
    final trimmed = email.trim();
    if (!_ensureConfigured() || state.busy || trimmed.isEmpty) return;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = await _repository.resendVerificationEmail(trimmed);
    if (isClosed) return;
    result.fold(
      (failure) => _emitFailure(failure),
      (_) => emit(
        state.copyWith(
          busy: false,
          feedback: AuthFeedback.verificationResent,
          feedbackId: state.feedbackId + 1,
        ),
      ),
    );
  }

  Future<void> checkEmailVerified() async {
    if (!_ensureConfigured() || state.busy) return;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _repository.getCurrentUser();
      if (isClosed) return;
      await result.fold((failure) async => _emitFailure(failure), (user) async {
        if (user == null || !user.emailVerified) {
          emit(
            state.copyWith(
              busy: false,
              feedback: AuthFeedback.emailNotVerifiedYet,
              feedbackId: state.feedbackId + 1,
            ),
          );
          return;
        }
        await _evaluateSessionUser(user);
      });
    } finally {
      _handlingAction = false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    if (!_ensureConfigured() || state.busy) return false;
    _handlingAction = true;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _updatePassword(newPassword);
      if (isClosed) return false;
      return await result.fold(
        (failure) async {
          _emitFailure(failure);
          return false;
        },
        (_) async {
          final currentResult = await _repository.getCurrentUser();
          if (isClosed) return false;
          await currentResult.fold(
            (_) async => emit(
              state.copyWith(
                busy: false,
                status: AuthStatus.unauthenticated,
                clearUser: true,
                passwordRecoveryPending: false,
                feedback: AuthFeedback.passwordUpdated,
                feedbackId: state.feedbackId + 1,
              ),
            ),
            (user) async {
              if (user == null) {
                emit(
                  state.copyWith(
                    busy: false,
                    status: AuthStatus.unauthenticated,
                    clearUser: true,
                    passwordRecoveryPending: false,
                    feedback: AuthFeedback.passwordUpdated,
                    feedbackId: state.feedbackId + 1,
                  ),
                );
                return;
              }
              await _evaluateSessionUser(
                user,
                clearRecovery: true,
                successFeedback: AuthFeedback.passwordUpdated,
              );
            },
          );
          return true;
        },
      );
    } finally {
      _handlingAction = false;
    }
  }

  void cancelPasswordRecovery() {
    if (!state.passwordRecoveryPending &&
        state.status != AuthStatus.passwordRecovery) {
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        passwordRecoveryPending: false,
      ),
    );
  }

  Future<void> _onAuthEvent(AuthSessionEvent event) async {
    if (isClosed) return;
    switch (event) {
      case AuthSessionPasswordRecovery(:final user):
        emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.passwordRecovery,
            user: user,
            passwordRecoveryPending: true,
            feedback: AuthFeedback.none,
          ),
        );
      case AuthSessionSignedOut():
        if (_handlingAction) return;
        emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            pendingHasLocalData: false,
            passwordRecoveryPending: false,
          ),
        );
      case AuthSessionSignedIn(:final user):
        if (_handlingAction) return;
        if (state.status == AuthStatus.passwordRecovery &&
            state.passwordRecoveryPending) {
          return;
        }
        if (state.status == AuthStatus.authenticated &&
            state.user?.id == user.id) {
          emit(state.copyWith(user: user));
          return;
        }
        await _evaluateSessionUser(user);
      case AuthSessionFailure(:final failure):
        _emitFailure(failure);
    }
  }

  Future<void> _evaluateSessionUser(
    AuthUser user, {
    bool markInitialized = false,
    bool clearRecovery = false,
    AuthFeedback? successFeedback,
  }) async {
    final result = await evaluateAuthenticatedUser(_repository, user);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          initialized: markInitialized ? true : state.initialized,
          busy: false,
          status: AuthStatus.unauthenticated,
          clearUser: true,
          passwordRecoveryPending: clearRecovery
              ? false
              : state.passwordRecoveryPending,
          feedback: _mapFailure(failure),
          feedbackId: state.feedbackId + 1,
        ),
      ),
      (outcome) => _applyOutcome(
        outcome,
        markInitialized: markInitialized,
        clearRecovery: clearRecovery,
        successFeedback: successFeedback,
      ),
    );
  }

  void _applyOutcome(
    AuthOutcome outcome, {
    bool markInitialized = false,
    bool clearRecovery = false,
    bool linkedJustNow = false,
    AuthFeedback? successFeedback,
  }) {
    final initialized = markInitialized ? true : state.initialized;
    final recoveryPending = clearRecovery
        ? false
        : state.passwordRecoveryPending;
    switch (outcome) {
      case AuthSignedIn(:final user):
        final feedback =
            successFeedback ??
            (linkedJustNow ? AuthFeedback.ledgerLinked : AuthFeedback.none);
        emit(
          state.copyWith(
            initialized: initialized,
            busy: false,
            status: AuthStatus.authenticated,
            user: user,
            clearPendingEmail: true,
            pendingHasLocalData: false,
            passwordRecoveryPending: recoveryPending,
            feedback: feedback,
            feedbackId: feedback == AuthFeedback.none
                ? state.feedbackId
                : state.feedbackId + 1,
          ),
        );
      case AuthEmailVerificationRequired(:final email):
        emit(
          state.copyWith(
            initialized: initialized,
            busy: false,
            status: AuthStatus.emailVerificationRequired,
            clearUser: true,
            pendingEmail: email,
            pendingHasLocalData: false,
            passwordRecoveryPending: recoveryPending,
            feedback: AuthFeedback.none,
          ),
        );
      case AuthLinkConfirmationRequired(:final user, :final hasLocalData):
        emit(
          state.copyWith(
            initialized: initialized,
            busy: false,
            status: AuthStatus.linkConfirmationRequired,
            user: user,
            clearPendingEmail: true,
            pendingHasLocalData: hasLocalData,
            passwordRecoveryPending: recoveryPending,
            feedback: AuthFeedback.none,
          ),
        );
      case AuthAccountMismatchBlocked():
        emit(
          state.copyWith(
            initialized: initialized,
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            clearPendingEmail: true,
            pendingHasLocalData: false,
            passwordRecoveryPending: recoveryPending,
            feedback: AuthFeedback.accountMismatchBlocked,
            feedbackId: state.feedbackId + 1,
          ),
        );
    }
  }

  bool _ensureConfigured() {
    if (state.isConfigured) return true;
    emit(
      state.copyWith(
        feedback: AuthFeedback.unconfigured,
        feedbackId: state.feedbackId + 1,
      ),
    );
    return false;
  }

  void _emitFailure(AppFailure failure) {
    emit(
      state.copyWith(
        busy: false,
        feedback: _mapFailure(failure),
        feedbackId: state.feedbackId + 1,
      ),
    );
  }

  static AuthFeedback _mapFailure(AppFailure failure) =>
      switch (failure.errorCode) {
        AppErrorCode.network => AuthFeedback.networkError,
        AppErrorCode.auth => AuthFeedback.authError,
        _ => AuthFeedback.genericError,
      };

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    _routing.dispose();
    return super.close();
  }
}
