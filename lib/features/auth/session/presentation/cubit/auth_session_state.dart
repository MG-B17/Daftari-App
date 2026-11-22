import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../domain/entities/auth_user.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  emailVerificationRequired,
  linkConfirmationRequired,
  passwordRecovery,
}

enum AuthFeedback {
  none,
  accountMismatchBlocked,
  authError,
  networkError,
  unconfigured,
  genericError,
  verificationResent,
  emailNotVerifiedYet,
  passwordResetSent,
  passwordUpdated,
  signedOut,
  ledgerLinked,
}

AuthFeedback mapAuthFailureToFeedback(AppFailure failure) =>
    switch (failure.errorCode) {
      AppErrorCode.network => AuthFeedback.networkError,
      AppErrorCode.auth => AuthFeedback.authError,
      _ => AuthFeedback.genericError,
    };

final class AuthSessionState extends Equatable {
  const AuthSessionState({
    this.initialized = false,
    this.isConfigured = false,
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.pendingEmail,
    this.pendingHasLocalData = false,
    this.busy = false,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
    this.passwordRecoveryPending = false,
  });

  final bool initialized;
  final bool isConfigured;
  final AuthStatus status;
  final AuthUser? user;
  final String? pendingEmail;
  final bool pendingHasLocalData;
  final bool busy;
  final AuthFeedback feedback;
  final int feedbackId;
  final bool passwordRecoveryPending;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthSessionState copyWith({
    bool? initialized,
    bool? isConfigured,
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    String? pendingEmail,
    bool clearPendingEmail = false,
    bool? pendingHasLocalData,
    bool? busy,
    AuthFeedback? feedback,
    int? feedbackId,
    bool? passwordRecoveryPending,
  }) => AuthSessionState(
    initialized: initialized ?? this.initialized,
    isConfigured: isConfigured ?? this.isConfigured,
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    pendingEmail: clearPendingEmail
        ? null
        : (pendingEmail ?? this.pendingEmail),
    pendingHasLocalData: pendingHasLocalData ?? this.pendingHasLocalData,
    busy: busy ?? this.busy,
    feedback: feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
    passwordRecoveryPending:
        passwordRecoveryPending ?? this.passwordRecoveryPending,
  );

  @override
  List<Object?> get props => [
    initialized,
    isConfigured,
    status,
    user,
    pendingEmail,
    pendingHasLocalData,
    busy,
    feedback,
    feedbackId,
    passwordRecoveryPending,
  ];
}
