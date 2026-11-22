import '../entities/auth_outcome.dart';

/// Identifies an in-flight form auth operation so the session coordinator can
/// suppress duplicate provider events for the same account while still letting
/// genuinely newer session changes invalidate stale results.
final class AuthSessionActionToken {
  const AuthSessionActionToken({
    required this.epoch,
    required this.nonSignOutEpoch,
  });

  final int epoch;
  final int nonSignOutEpoch;
}

/// Shared coordination contract consumed by auth form features to transfer
/// operation outcomes to the app-wide session coordinator without importing its
/// presentation implementation.
abstract interface class AuthSessionCoordinator {
  bool get isConfigured;

  String? get currentUserId;

  String? get pendingEmail;

  bool get isAuthenticated;

  bool get requiresLinkConfirmation;

  AuthSessionActionToken beginAuthAction({String? email, String? userId});

  bool isActionCurrent(AuthSessionActionToken token);

  bool applyAuthOutcome(AuthSessionActionToken token, AuthOutcome outcome);

  void endAuthAction(AuthSessionActionToken token);

  Future<bool> completePasswordRecovery(AuthSessionActionToken token);

  Future<bool> cancelPasswordRecovery();
}
