import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../security/presentation/cubit/app_lock_cubit.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';

/// Listens for terminal restore and device-transfer outcomes on [RestoreCubit]
/// and displays the localized shared dialog once per submission on the active
/// route.
class RestoreFeedbackListener extends StatefulWidget {
  const RestoreFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  State<RestoreFeedbackListener> createState() =>
      _RestoreFeedbackListenerState();
}

class _RestoreFeedbackListenerState extends State<RestoreFeedbackListener> {
  bool _presentingDialog = false;

  bool _canPresent(BuildContext context) {
    final locked = context.read<AppLockCubit?>()?.state.locked ?? false;
    if (locked) return false;
    if (!TickerMode.of(context)) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  Future<void> _handleFeedback(
    BuildContext context,
    RestoreViewState state,
  ) async {
    if (!mounted || _presentingDialog || !_canPresent(context)) return;
    final cubit = context.read<RestoreCubit?>();
    if (cubit == null) return;
    if (!cubit.consumeFeedback(state.feedbackId)) return;

    final l10n = context.l10n;
    _presentingDialog = true;
    try {
      switch (state.feedback) {
        case RestoreFeedback.none:
          return;
        case RestoreFeedback.completedTransferred:
          await AppSuccessDialog.show(
            context,
            title: l10n.restoreCompletedTitle,
            message: l10n.restoreCompletedTransferredMessage,
          );
        case RestoreFeedback.completedSameDevice:
          await AppSuccessDialog.show(
            context,
            title: l10n.restoreCompletedTitle,
            message: l10n.restoreCompletedSameDeviceMessage,
          );
        case RestoreFeedback.cloudVersionChanged:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreRefreshRequiredTitle,
            message: l10n.restoreCloudVersionChangedNotice,
          );
        case RestoreFeedback.localLedgerChanged:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreRefreshRequiredTitle,
            message: l10n.restoreLocalLedgerChangedNotice,
          );
        case RestoreFeedback.accountMismatch:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreAccountMismatchTitle,
            message: l10n.restoreAccountMismatchMessage,
          );
        case RestoreFeedback.offline:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreOfflineTitle,
            message: l10n.restoreOfflineMessage,
          );
        case RestoreFeedback.interrupted:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreInterruptedTitle,
            message: l10n.restoreInterruptedMessage,
          );
        case RestoreFeedback.authError:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreFailedTitle,
            message: l10n.restoreAuthErrorMessage,
          );
        case RestoreFeedback.failed:
          await AppErrorDialog.show(
            context,
            title: l10n.restoreFailedTitle,
            message: l10n.restoreFailedMessage,
          );
      }
    } finally {
      _presentingDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RestoreCubit?>();
    if (cubit == null) return widget.child;
    return BlocListener<RestoreCubit, RestoreViewState>(
      listenWhen: (previous, next) =>
          previous.feedbackId != next.feedbackId &&
          next.feedback != RestoreFeedback.none,
      listener: (context, state) => unawaited(_handleFeedback(context, state)),
      child: widget.child,
    );
  }
}
