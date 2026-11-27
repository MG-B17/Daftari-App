import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../security/presentation/cubit/app_lock_cubit.dart';
import '../../../security/presentation/cubit/app_lock_state.dart';
import '../cubit/backup_cubit.dart';
import '../models/backup_view_state.dart';

/// Listens for terminal manual backup outcomes on [BackupCubit] and displays
/// the localized shared dialog once per submission on the active route.
///
/// Scheduled and background backup runs do not increment `manualFeedbackId`
/// and remain silent.
class BackupFeedbackListener extends StatefulWidget {
  const BackupFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  State<BackupFeedbackListener> createState() => _BackupFeedbackListenerState();
}

class _BackupFeedbackListenerState extends State<BackupFeedbackListener> {
  bool _presentingDialog = false;
  bool _recheckScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ModalRoute.of(context);
    TickerMode.of(context);
    _schedulePendingFeedbackCheck();
  }

  void _schedulePendingFeedbackCheck() {
    if (_recheckScheduled || _presentingDialog) return;
    final cubit = context.read<BackupCubit?>();
    if (cubit == null) return;
    final state = cubit.state;
    if (state.manualFeedback == BackupManualFeedback.none ||
        !cubit.hasUnconsumedManualFeedback(state.manualFeedbackId)) {
      return;
    }
    _recheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recheckScheduled = false;
      if (!mounted) return;
      final currentCubit = context.read<BackupCubit?>();
      if (currentCubit == null) return;
      final currentState = currentCubit.state;
      if (currentState.manualFeedback == BackupManualFeedback.none) return;
      unawaited(_handleFeedback(context, currentState));
    });
  }

  bool _canPresent(BuildContext context) {
    final locked = context.read<AppLockCubit?>()?.state.locked ?? false;
    if (locked) return false;
    if (!TickerMode.of(context)) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  Future<void> _handleFeedback(
    BuildContext context,
    BackupViewState state,
  ) async {
    if (!mounted || _presentingDialog || !_canPresent(context)) return;
    final cubit = context.read<BackupCubit?>();
    if (cubit == null) return;
    if (!cubit.consumeManualFeedback(state.manualFeedbackId)) return;

    final l10n = context.l10n;
    _presentingDialog = true;
    try {
      switch (state.manualFeedback) {
        case BackupManualFeedback.none:
          return;
        case BackupManualFeedback.confirmed:
          await AppSuccessDialog.show(
            context,
            title: l10n.backupManualSuccessTitle,
            message: l10n.backupManualSuccessMessage,
          );
        case BackupManualFeedback.nothingToUpload:
          await AppSuccessDialog.show(
            context,
            title: l10n.backupManualNothingToUploadTitle,
            message: l10n.backupManualNothingToUploadMessage,
          );
        case BackupManualFeedback.alreadyRunning:
          await AppErrorDialog.show(
            context,
            title: l10n.backupManualAlreadyRunningTitle,
            message: l10n.backupManualAlreadyRunningMessage,
          );
        case BackupManualFeedback.offline:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupManualOfflineMessage,
          );
        case BackupManualFeedback.signedOut:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupAccountSignedOutSubtitle,
          );
        case BackupManualFeedback.emailNotVerified:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupManualEmailUnverifiedMessage,
          );
        case BackupManualFeedback.ledgerUnlinked:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupManualLedgerUnlinkedMessage,
          );
        case BackupManualFeedback.accountMismatch:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.authErrorAccountMismatch,
          );
        case BackupManualFeedback.inactiveDevice:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupInactiveDeviceHint,
          );
        case BackupManualFeedback.authError:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: l10n.backupManualAuthErrorMessage,
          );
        case BackupManualFeedback.failed:
          await AppErrorDialog.show(
            context,
            title: l10n.backupStatusFailed,
            message: state.lastConfirmedAt == null
                ? l10n.backupFailedFirstHint
                : l10n.backupFailedHint,
          );
      }
    } finally {
      _presentingDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BackupCubit?>();
    if (cubit == null) return widget.child;
    Widget child = BlocListener<BackupCubit, BackupViewState>(
      listenWhen: (previous, next) =>
          previous.manualFeedbackId != next.manualFeedbackId &&
          next.manualFeedback != BackupManualFeedback.none,
      listener: (context, state) => unawaited(_handleFeedback(context, state)),
      child: widget.child,
    );
    final lockCubit = context.read<AppLockCubit?>();
    if (lockCubit != null) {
      child = BlocListener<AppLockCubit, AppLockState>(
        listenWhen: (previous, next) => previous.locked && !next.locked,
        listener: (context, _) => _schedulePendingFeedbackCheck(),
        child: child,
      );
    }
    return child;
  }
}
