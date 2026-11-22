import 'package:equatable/equatable.dart';

import '../../../session/presentation/cubit/auth_session_state.dart';

final class UpdatePasswordState extends Equatable {
  const UpdatePasswordState({
    this.busy = false,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
  });

  final bool busy;
  final AuthFeedback feedback;
  final int feedbackId;

  UpdatePasswordState copyWith({
    bool? busy,
    AuthFeedback? feedback,
    int? feedbackId,
  }) => UpdatePasswordState(
    busy: busy ?? this.busy,
    feedback: feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
  );

  @override
  List<Object?> get props => [busy, feedback, feedbackId];
}
