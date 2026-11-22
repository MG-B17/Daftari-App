import 'package:equatable/equatable.dart';

import '../../../session/presentation/cubit/auth_session_state.dart';

final class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.busy = false,
    this.sent = false,
    this.sentEmail,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
  });

  final bool busy;
  final bool sent;
  final String? sentEmail;
  final AuthFeedback feedback;
  final int feedbackId;

  ForgotPasswordState copyWith({
    bool? busy,
    bool? sent,
    String? sentEmail,
    AuthFeedback? feedback,
    int? feedbackId,
  }) => ForgotPasswordState(
    busy: busy ?? this.busy,
    sent: sent ?? this.sent,
    sentEmail: sentEmail ?? this.sentEmail,
    feedback: feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
  );

  @override
  List<Object?> get props => [busy, sent, sentEmail, feedback, feedbackId];
}
