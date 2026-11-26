import 'package:equatable/equatable.dart';

import '../../../session/presentation/cubit/auth_session_state.dart';

enum VerifyEmailPendingAction { none, resend, check }

final class VerifyEmailState extends Equatable {
  const VerifyEmailState({
    this.pendingAction = VerifyEmailPendingAction.none,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
  });

  final VerifyEmailPendingAction pendingAction;
  final AuthFeedback feedback;
  final int feedbackId;

  bool get busy => pendingAction != VerifyEmailPendingAction.none;
  bool get isResending => pendingAction == VerifyEmailPendingAction.resend;
  bool get isChecking => pendingAction == VerifyEmailPendingAction.check;

  VerifyEmailState copyWith({
    VerifyEmailPendingAction? pendingAction,
    AuthFeedback? feedback,
    int? feedbackId,
  }) => VerifyEmailState(
    pendingAction: pendingAction ?? this.pendingAction,
    feedback: feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
  );

  @override
  List<Object?> get props => [pendingAction, feedback, feedbackId];
}
