import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';
import 'restore_labels.dart';
import 'restore_preview_cards.dart';

/// Dispatches the current [RestorePhase] to the corresponding status, notice,
/// recovery, completion, or preview/consent section.
class RestoreBodySection extends StatelessWidget {
  const RestoreBodySection({super.key, required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();

    switch (state.phase) {
      case RestorePhase.initial:
      case RestorePhase.loading:
        return const DaftariLoading.screen(
          key: ValueKey('restore-loading-indicator'),
        );
      case RestorePhase.signedOut:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-signed-out'),
          icon: Icons.person_off_outlined,
          title: l10n.restoreSignedOutTitle,
          message: l10n.restoreSignedOutMessage,
        );
      case RestorePhase.emailNotVerified:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-email-unverified'),
          icon: Icons.mark_email_unread_outlined,
          title: l10n.restoreEmailUnverifiedTitle,
          message: l10n.restoreEmailUnverifiedMessage,
        );
      case RestorePhase.accountMismatch:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-account-mismatch'),
          icon: Icons.block_rounded,
          isError: true,
          title: l10n.restoreAccountMismatchTitle,
          message: l10n.restoreAccountMismatchMessage,
        );
      case RestorePhase.offline:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-offline'),
          icon: Icons.wifi_off_rounded,
          title: l10n.restoreOfflineTitle,
          message: l10n.restoreOfflineMessage,
          action: AppButton(
            key: const ValueKey('restore-retry'),
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            fullWidth: true,
            onPressed: cubit == null || state.isBusy
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.missingBackup:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-missing-backup'),
          icon: Icons.cloud_off_outlined,
          title: l10n.restoreMissingBackupTitle,
          message: l10n.restoreMissingBackupMessage,
          action: AppButton(
            key: const ValueKey('restore-retry'),
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.outlined,
            fullWidth: true,
            onPressed: cubit == null || state.isBusy
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.error:
        return RestoreNoticeCard(
          key: const ValueKey('restore-state-error'),
          icon: Icons.error_outline_rounded,
          isError: true,
          title: l10n.errorTitle,
          message: l10n.errorMessage,
          action: AppButton(
            key: const ValueKey('restore-retry'),
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            fullWidth: true,
            onPressed: cubit == null || state.isBusy
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.interruptedRecovery:
        return RestoreInterruptedTransferCard(state: state);
      case RestorePhase.completed:
        return RestoreCompletedCard(state: state);
      case RestorePhase.previewReady:
      case RestorePhase.confirmingPrimary:
      case RestorePhase.confirmingReplacement:
        return RestorePreviewAndConsentSection(state: state);
      case RestorePhase.executing:
        return state.pendingTransfer != null
            ? RestoreInterruptedTransferCard(state: state)
            : RestorePreviewAndConsentSection(state: state);
    }
  }
}

class RestoreInterruptedTransferCard extends StatelessWidget {
  const RestoreInterruptedTransferCard({super.key, required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();
    final transfer = state.pendingTransfer;
    final cloud = transfer?.cloudPreview ?? state.cloudPreview;
    final isExecuting = state.phase == RestorePhase.executing;
    final isCancelling = state.isCancellingInterrupted;
    final isBusy = state.isBusy;

    return Container(
      key: const ValueKey('restore-state-interrupted'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.cardPaperSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: context.colorScheme.primary,
          width: AppSpacing.selectedStroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExecuting) ...[
            const LinearProgressIndicator(
              key: ValueKey('restore-executing-progress'),
            ),
            SizedBox(height: AppSpacing.compact),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsIconBox(icon: Icons.sync_problem_rounded),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.restoreInterruptedTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.restoreInterruptedMessage,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cloud != null) ...[
            SizedBox(height: AppSpacing.compact),
            Text(
              cloud.confirmedAt.confirmedAtLabel(context),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.compact),
          Text(
            l10n.restoreInterruptedUploadsBlockedNote,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppButton(
            key: const ValueKey('restore-resume-transfer'),
            label: l10n.restoreResumeAction,
            icon: Icons.play_arrow_rounded,
            fullWidth: true,
            isLoading: isExecuting,
            onPressed: cubit == null || isBusy
                ? null
                : () => unawaited(cubit.resumeInterruptedTransfer()),
          ),
          if (transfer != null && transfer.canCancelBeforeServerTakeover) ...[
            SizedBox(height: AppSpacing.sm),
            AppButton(
              key: const ValueKey('restore-cancel-interrupted'),
              label: l10n.cancel,
              variant: AppButtonVariant.outlined,
              fullWidth: true,
              isLoading: isCancelling,
              onPressed: cubit == null || isBusy
                  ? null
                  : () => unawaited(cubit.cancelInterruptedTransfer()),
            ),
          ],
        ],
      ),
    );
  }
}

class RestoreCompletedCard extends StatelessWidget {
  const RestoreCompletedCard({super.key, required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cloud = state.cloudPreview;
    final local = state.localLedger;

    return Container(
      key: const ValueKey('restore-state-completed'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.paymentSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.appColors.paymentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: context.appColors.paymentColor,
                size: AppSpacing.iconMedium,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.restoreCompletedTitle,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.appColors.paymentColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            state.authorityTransferred
                ? l10n.restoreCompletedTransferredMessage
                : l10n.restoreCompletedSameDeviceMessage,
            style: context.textTheme.bodyMedium,
          ),
          if (cloud != null) ...[
            SizedBox(height: AppSpacing.compact),
            Text(
              cloud.confirmedAt.confirmedAtLabel(context),
              style: context.textTheme.bodySmall,
            ),
          ],
          if (local != null) ...[
            Text(
              l10n.restoreCustomersCount(local.customerCount),
              style: context.textTheme.bodySmall,
            ),
            Text(
              l10n.restoreTransactionsCount(local.transactionCount),
              style: context.textTheme.bodySmall,
            ),
            Text(
              l10n.backupPendingChanges(local.pendingChangesCount),
              style: context.textTheme.bodySmall,
            ),
          ],
          SizedBox(height: AppSpacing.md),
          AppButton(
            key: const ValueKey('restore-done-button'),
            label: l10n.restoreDoneAction,
            fullWidth: true,
            onPressed: () {
              final router = GoRouter.maybeOf(context);
              if (router != null && router.canPop()) {
                context.pop();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

class RestoreNoticeCard extends StatelessWidget {
  const RestoreNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final borderColor = isError
        ? context.appColors.creditColor
        : context.colorScheme.outline;
    final surfaceColor = isError
        ? context.appColors.creditSurface
        : context.appColors.cardPaperSurface;

    return Container(
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIconBox(icon: icon),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: isError ? context.appColors.creditColor : null,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(message, style: context.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[SizedBox(height: AppSpacing.md), action!],
        ],
      ),
    );
  }
}
