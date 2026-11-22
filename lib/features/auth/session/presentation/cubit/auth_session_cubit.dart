import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/ledger_link_status.dart';
import '../../domain/repositories/auth_session_coordinator.dart';
import '../../domain/repositories/auth_session_repository.dart';
import '../../domain/usecases/confirm_ledger_link_usecase.dart';
import '../../domain/usecases/ledger_link_evaluator.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import 'auth_session_state.dart';

class AuthSessionCubit extends Cubit<AuthSessionState>
    implements AuthSessionCoordinator, Listenable {
  AuthSessionCubit(this._repository, this._signOut, this._confirmLedgerLink)
    : super(AuthSessionState(isConfigured: _repository.isConfigured));

  final AuthSessionRepository _repository;
  final SignOutUseCase _signOut;
  final ConfirmLedgerLinkUseCase _confirmLedgerLink;

  final ValueNotifier<int> _routing = ValueNotifier<int>(0);
  StreamSubscription<AuthSessionEvent>? _authSubscription;
  Future<void>? _initializing;
  int _sessionEpoch = 0;
  int _nonSignOutEpoch = 0;
  int _activeActionEpoch = 0;
  String? _pendingAuthActionEmail;
  String? _activeActionUserId;
  int _consumedFeedbackId = 0;
  bool _linkPromptOpen = false;

  @override
  bool get isConfigured => state.isConfigured;

  @override
  String? get currentUserId => state.user?.id;

  @override
  String? get pendingEmail => state.pendingEmail;

  @override
  bool get isAuthenticated => state.isAuthenticated;

  @override
  bool get requiresLinkConfirmation =>
      state.status == AuthStatus.linkConfirmationRequired;

  @override
  AuthSessionActionToken beginAuthAction({String? email, String? userId}) {
    final epoch = ++_sessionEpoch;
    final nonSignOutEpoch = ++_nonSignOutEpoch;
    _activeActionEpoch = epoch;
    final trimmedEmail = email?.trim().toLowerCase();
    _pendingAuthActionEmail = trimmedEmail == null || trimmedEmail.isEmpty
        ? null
        : trimmedEmail;
    _activeActionUserId = userId;
    return AuthSessionActionToken(
      epoch: epoch,
      nonSignOutEpoch: nonSignOutEpoch,
    );
  }

  @override
  bool isActionCurrent(AuthSessionActionToken token) =>
      token.nonSignOutEpoch == _nonSignOutEpoch;

  @override
  bool applyAuthOutcome(AuthSessionActionToken token, AuthOutcome outcome) {
    if (isClosed) return false;
    if (!_canApplyOutcome(
      outcome,
      epoch: token.epoch,
      nonSignOutEpoch: token.nonSignOutEpoch,
    )) {
      return false;
    }
    _applyOutcome(outcome);
    return true;
  }

  @override
  void endAuthAction(AuthSessionActionToken token) =>
      _clearActiveAction(token.epoch);

  void _clearActiveAction([int? expectedEpoch]) {
    if (expectedEpoch != null && _activeActionEpoch != expectedEpoch) return;
    _activeActionEpoch = 0;
    _pendingAuthActionEmail = null;
    _activeActionUserId = null;
  }

  bool _isExpectedActiveActionSignIn(AuthUser user) {
    if (_activeActionEpoch == 0) return false;
    if (_activeActionUserId != null && _activeActionUserId == user.id) {
      return true;
    }
    if (_pendingAuthActionEmail != null &&
        user.email.trim().toLowerCase() == _pendingAuthActionEmail) {
      _activeActionUserId = user.id;
      return true;
    }
    return false;
  }

  bool _canApplyOutcome(
    AuthOutcome outcome, {
    required int epoch,
    required int nonSignOutEpoch,
  }) => switch (outcome) {
    AuthSignedIn() || AuthLinkConfirmationRequired() => epoch == _sessionEpoch,
    AuthAccountMismatchBlocked() ||
    AuthEmailVerificationRequired() => nonSignOutEpoch == _nonSignOutEpoch,
  };

  bool consumeFeedback(int feedbackId) {
    if (feedbackId <= _consumedFeedbackId) return false;
    _consumedFeedbackId = feedbackId;
    return true;
  }

  bool tryBeginLinkPrompt() {
    if (_linkPromptOpen) return false;
    _linkPromptOpen = true;
    return true;
  }

  void endLinkPrompt() {
    _linkPromptOpen = false;
  }

  @override
  void addListener(VoidCallback listener) => _routing.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _routing.removeListener(listener);

  @override
  void emit(AuthSessionState state) {
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
      final epoch = ++_sessionEpoch;
      final nonSignOutEpoch = ++_nonSignOutEpoch;
      final currentResult = await _repository.getCurrentUser();
      if (isClosed) return;
      if (epoch != _sessionEpoch) {
        if (!state.initialized) {
          emit(state.copyWith(initialized: true, isConfigured: configured));
        }
        return;
      }
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
          await _evaluateSessionUser(
            user,
            epoch: epoch,
            nonSignOutEpoch: nonSignOutEpoch,
            markInitialized: true,
          );
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

  Future<void> confirmLedgerLink({
    required bool confirmed,
    String? expectedUserId,
  }) async {
    final pendingUser = state.user;
    if (state.status != AuthStatus.linkConfirmationRequired ||
        pendingUser == null ||
        state.busy) {
      return;
    }
    if (expectedUserId != null && pendingUser.id != expectedUserId) {
      return;
    }
    final epoch = ++_sessionEpoch;
    final nonSignOutEpoch = ++_nonSignOutEpoch;
    _activeActionEpoch = epoch;
    _pendingAuthActionEmail = null;
    _activeActionUserId = pendingUser.id;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _confirmLedgerLink(
        user: pendingUser,
        confirmed: confirmed,
      );
      if (isClosed) return;
      result.fold(
        (failure) {
          if (nonSignOutEpoch != _nonSignOutEpoch) return;
          emit(
            state.copyWith(
              busy: false,
              status: AuthStatus.unauthenticated,
              clearUser: true,
              pendingHasLocalData: false,
              feedback: mapAuthFailureToFeedback(failure),
              feedbackId: state.feedbackId + 1,
            ),
          );
        },
        (outcome) {
          if (outcome == null) {
            if (nonSignOutEpoch != _nonSignOutEpoch) return;
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
          if (!_canApplyOutcome(
            outcome,
            epoch: epoch,
            nonSignOutEpoch: nonSignOutEpoch,
          )) {
            return;
          }
          _applyOutcome(outcome, linkedJustNow: outcome is AuthSignedIn);
        },
      );
    } finally {
      _clearActiveAction(epoch);
    }
  }

  Future<void> signOut() async {
    if (state.busy) return;
    ++_sessionEpoch;
    final nonSignOutEpoch = ++_nonSignOutEpoch;
    _clearActiveAction();
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = await _signOut();
    if (isClosed || nonSignOutEpoch != _nonSignOutEpoch) return;
    result.fold(
      _emitFailure,
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
  }

  @override
  Future<bool> completePasswordRecovery(AuthSessionActionToken token) async {
    if (isClosed || token.epoch != _sessionEpoch) return false;
    final currentResult = await _repository.getCurrentUser();
    if (isClosed || token.epoch != _sessionEpoch) return false;
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
          epoch: token.epoch,
          nonSignOutEpoch: token.nonSignOutEpoch,
          clearRecovery: true,
          successFeedback: AuthFeedback.passwordUpdated,
        );
      },
    );
    return true;
  }

  @override
  Future<bool> cancelPasswordRecovery() async {
    if (!state.passwordRecoveryPending &&
        state.status != AuthStatus.passwordRecovery) {
      return true;
    }
    if (state.busy) return false;
    final recoveryUserId = state.user?.id;
    ++_sessionEpoch;
    final nonSignOutEpoch = ++_nonSignOutEpoch;
    _clearActiveAction();
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = recoveryUserId != null
        ? await _repository.signOut(expectedUserId: recoveryUserId)
        : await _signOut();
    if (isClosed || nonSignOutEpoch != _nonSignOutEpoch) return false;
    return result.fold<bool>(
      (failure) {
        _emitFailure(failure);
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            pendingHasLocalData: false,
            passwordRecoveryPending: false,
            feedback: AuthFeedback.none,
          ),
        );
        return true;
      },
    );
  }

  Future<void> _onAuthEvent(AuthSessionEvent event) async {
    if (isClosed) return;
    switch (event) {
      case AuthSessionPasswordRecovery(:final user):
        _clearActiveAction();
        final epoch = ++_sessionEpoch;
        final nonSignOutEpoch = ++_nonSignOutEpoch;
        await _evaluatePasswordRecoveryUser(
          user,
          epoch: epoch,
          nonSignOutEpoch: nonSignOutEpoch,
        );
      case AuthSessionSignedOut():
        _clearActiveAction();
        _sessionEpoch++;
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
        if (_isExpectedActiveActionSignIn(user)) return;
        if (state.status == AuthStatus.passwordRecovery &&
            state.passwordRecoveryPending) {
          return;
        }
        _clearActiveAction();
        final epoch = ++_sessionEpoch;
        final nonSignOutEpoch = ++_nonSignOutEpoch;
        if (state.status == AuthStatus.authenticated &&
            state.user?.id == user.id) {
          emit(state.copyWith(user: user));
          return;
        }
        await _evaluateSessionUser(
          user,
          epoch: epoch,
          nonSignOutEpoch: nonSignOutEpoch,
        );
      case AuthSessionFailure(:final failure):
        _emitFailure(failure);
    }
  }

  Future<void> _evaluatePasswordRecoveryUser(
    AuthUser user, {
    required int epoch,
    required int nonSignOutEpoch,
  }) async {
    final statusResult = await _repository.getLedgerLinkStatus(user.id);
    if (isClosed || epoch != _sessionEpoch) return;
    await statusResult.fold(
      (failure) async {
        await _repository.signOut(expectedUserId: user.id);
        if (isClosed || nonSignOutEpoch != _nonSignOutEpoch) return;
        emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            passwordRecoveryPending: false,
            feedback: mapAuthFailureToFeedback(failure),
            feedbackId: state.feedbackId + 1,
          ),
        );
      },
      (status) async {
        if (status == LedgerLinkStatus.linkedToOtherUser) {
          final signOutResult = await _repository.signOut(
            expectedUserId: user.id,
          );
          if (isClosed || nonSignOutEpoch != _nonSignOutEpoch) return;
          signOutResult.fold(
            (failure) => emit(
              state.copyWith(
                busy: false,
                status: AuthStatus.unauthenticated,
                clearUser: true,
                passwordRecoveryPending: false,
                feedback: mapAuthFailureToFeedback(failure),
                feedbackId: state.feedbackId + 1,
              ),
            ),
            (_) => emit(
              state.copyWith(
                busy: false,
                status: AuthStatus.unauthenticated,
                clearUser: true,
                clearPendingEmail: true,
                pendingHasLocalData: false,
                passwordRecoveryPending: false,
                feedback: AuthFeedback.accountMismatchBlocked,
                feedbackId: state.feedbackId + 1,
              ),
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            busy: false,
            status: AuthStatus.passwordRecovery,
            user: user,
            passwordRecoveryPending: true,
            feedback: AuthFeedback.none,
          ),
        );
      },
    );
  }

  Future<void> _evaluateSessionUser(
    AuthUser user, {
    required int epoch,
    required int nonSignOutEpoch,
    bool markInitialized = false,
    bool clearRecovery = false,
    AuthFeedback? successFeedback,
  }) async {
    final result = await evaluateAuthenticatedUser(_repository, user);
    if (isClosed) return;
    result.fold(
      (failure) {
        if (nonSignOutEpoch != _nonSignOutEpoch) {
          if (markInitialized && !state.initialized) {
            emit(state.copyWith(initialized: true));
          }
          return;
        }
        emit(
          state.copyWith(
            initialized: markInitialized ? true : state.initialized,
            busy: false,
            status: AuthStatus.unauthenticated,
            clearUser: true,
            passwordRecoveryPending: clearRecovery
                ? false
                : state.passwordRecoveryPending,
            feedback: mapAuthFailureToFeedback(failure),
            feedbackId: state.feedbackId + 1,
          ),
        );
      },
      (outcome) {
        if (!_canApplyOutcome(
          outcome,
          epoch: epoch,
          nonSignOutEpoch: nonSignOutEpoch,
        )) {
          if (markInitialized && !state.initialized) {
            emit(state.copyWith(initialized: true));
          }
          return;
        }
        _applyOutcome(
          outcome,
          markInitialized: markInitialized,
          clearRecovery: clearRecovery,
          successFeedback: successFeedback,
        );
      },
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

  void _emitFailure(AppFailure failure) {
    emit(
      state.copyWith(
        busy: false,
        feedback: mapAuthFailureToFeedback(failure),
        feedbackId: state.feedbackId + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    _routing.dispose();
    return super.close();
  }
}
