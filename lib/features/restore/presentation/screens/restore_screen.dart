import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../backup/presentation/widgets/backup_account_card.dart';
import '../../../backup/presentation/widgets/backup_labels.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../domain/entities/restore_entities.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';
import '../widgets/restore_confirmation_cards.dart';
import '../widgets/restore_labels.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key, this.state});

  final RestoreViewState? state;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  @override
  void initState() {
    super.initState();
    _ensurePreviewLoaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensurePreviewLoaded();
  }

  @override
  void didUpdateWidget(covariant RestoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensurePreviewLoaded();
  }

  void _ensurePreviewLoaded() {
    if (widget.state == null) {
      final cubit = context.read<RestoreCubit?>();
      if (cubit != null && cubit.state.phase == RestorePhase.initial) {
        unawaited(cubit.loadPreview());
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.restoreScreenTitle,
    body: RestoreViewStateBuilder(
      state: widget.state,
      builder: (context, view) => ListView(
        children: [
          if (view.isPreview) ...[
            const BackupPreviewBanner(),
            SizedBox(height: AppSpacing.settingsSectionGap),
          ],
          BackupAccountCard(
            shopName: view.accountShopName,
            email: view.accountEmail,
          ),
          SizedBox(height: AppSpacing.settingsSectionGap),
          _RestoreBody(state: view),
        ],
      ),
    ),
  );
}

class _RestoreBody extends StatelessWidget {
  const _RestoreBody({required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();

    switch (state.phase) {
      case RestorePhase.initial:
      case RestorePhase.loading:
        return Center(
          child: Padding(
            padding: AppSpacing.pagePadding,
            child: const CircularProgressIndicator(
              key: ValueKey('restore-loading-indicator'),
            ),
          ),
        );
      case RestorePhase.signedOut:
        return _RestoreNoticeCard(
          key: const ValueKey('restore-state-signed-out'),
          icon: Icons.person_off_outlined,
          title: l10n.restoreSignedOutTitle,
          message: l10n.restoreSignedOutMessage,
        );
      case RestorePhase.emailNotVerified:
        return _RestoreNoticeCard(
          key: const ValueKey('restore-state-email-unverified'),
          icon: Icons.mark_email_unread_outlined,
          title: l10n.restoreEmailUnverifiedTitle,
          message: l10n.restoreEmailUnverifiedMessage,
        );
      case RestorePhase.accountMismatch:
        return _RestoreNoticeCard(
          key: const ValueKey('restore-state-account-mismatch'),
          icon: Icons.block_rounded,
          isError: true,
          title: l10n.restoreAccountMismatchTitle,
          message: l10n.restoreAccountMismatchMessage,
        );
      case RestorePhase.offline:
        return _RestoreNoticeCard(
          key: const ValueKey('restore-state-offline'),
          icon: Icons.wifi_off_rounded,
          title: l10n.restoreOfflineTitle,
          message: l10n.restoreOfflineMessage,
          action: AppButton(
            key: const ValueKey('restore-retry'),
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            fullWidth: true,
            onPressed: cubit == null
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.missingBackup:
        return _RestoreNoticeCard(
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
            onPressed: cubit == null
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.error:
        return _RestoreNoticeCard(
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
            onPressed: cubit == null
                ? null
                : () => unawaited(cubit.loadPreview()),
          ),
        );
      case RestorePhase.interruptedRecovery:
        return _InterruptedTransferCard(state: state);
      case RestorePhase.completed:
        return _RestoreCompletedCard(state: state);
      case RestorePhase.previewReady:
      case RestorePhase.confirmingPrimary:
      case RestorePhase.confirmingReplacement:
      case RestorePhase.executing:
        return _RestorePreviewAndConsentContent(state: state);
    }
  }
}

class _RestorePreviewAndConsentContent extends StatelessWidget {
  const _RestorePreviewAndConsentContent({required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();
    final cloud = state.cloudPreview;
    final local = state.localLedger;
    final isConfirming =
        state.phase == RestorePhase.confirmingPrimary ||
        state.phase == RestorePhase.confirmingReplacement;
    final isExecuting = state.phase == RestorePhase.executing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.refreshReason case final reason?) ...[
          _RefreshReasonBanner(reason: reason),
          SizedBox(height: AppSpacing.compact),
        ],
        if (isExecuting) ...[
          const LinearProgressIndicator(
            key: ValueKey('restore-executing-progress'),
          ),
          SizedBox(height: AppSpacing.compact),
        ],
        if (cloud != null) ...[
          _CloudSnapshotCard(cloud: cloud),
          SizedBox(height: AppSpacing.settingsSectionGap),
        ],
        _ConsequenceCard(requiresTakeover: state.requiresTakeover),
        SizedBox(height: AppSpacing.settingsSectionGap),
        if (local != null) ...[
          _LocalLedgerCard(local: local),
          SizedBox(height: AppSpacing.settingsSectionGap),
        ],
        if (state.phase == RestorePhase.confirmingPrimary)
          RestorePrimaryConfirmationCard(state: state)
        else if (state.phase == RestorePhase.confirmingReplacement)
          RestoreReplacementConfirmationCard(state: state)
        else if (!isConfirming)
          AppButton(
            key: const ValueKey('restore-start-button'),
            label: state.requiresTakeover
                ? l10n.restoreAndTransferAction
                : l10n.restoreOnlyAction,
            icon: state.requiresTakeover
                ? Icons.phonelink_setup_rounded
                : Icons.cloud_download_outlined,
            fullWidth: true,
            isLoading: isExecuting,
            onPressed: isExecuting ? null : cubit?.requestRestoreConfirmation,
          ),
      ],
    );
  }
}

class _RefreshReasonBanner extends StatelessWidget {
  const _RefreshReasonBanner({required this.reason});

  final RestoreRefreshReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (reason) {
      RestoreRefreshReason.cloudVersionOrDeviceChanged =>
        l10n.restoreCloudVersionChangedNotice,
      RestoreRefreshReason.localLedgerChanged =>
        l10n.restoreLocalLedgerChangedNotice,
    };
    return Container(
      key: const ValueKey('restore-refresh-notice'),
      width: double.infinity,
      padding: AppSpacing.authNotePadding,
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: AppSpacing.settingsOptionRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppSpacing.iconSmall,
            color: context.colorScheme.onPrimaryContainer,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSnapshotCard extends StatelessWidget {
  const _CloudSnapshotCard({required this.cloud});

  final CloudBackupSnapshotPreview cloud;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final captionStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Container(
      key: const ValueKey('restore-cloud-preview-card'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.cardPaperSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsIconBox(icon: Icons.cloud_done_outlined),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.restoreCloudSnapshotTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      cloud.confirmedAt.confirmedAtLabel(context),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.compact),
          if (cloud.hasZeroRows)
            Text(
              l10n.restoreZeroRowsSnapshotNote,
              key: const ValueKey('restore-zero-rows-note'),
              style: captionStyle,
            )
          else ...[
            Text(
              l10n.restoreCustomersCount(cloud.customerCount),
              style: captionStyle,
            ),
            Text(
              l10n.restoreTransactionsCount(cloud.transactionCount),
              style: captionStyle,
            ),
            if (cloud.deletedAndAuditCount > 0)
              Text(
                l10n.restoreHistoryCount(cloud.deletedAndAuditCount),
                style: captionStyle,
              ),
          ],
        ],
      ),
    );
  }
}

class _ConsequenceCard extends StatelessWidget {
  const _ConsequenceCard({required this.requiresTakeover});

  final bool requiresTakeover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('restore-consequence-card'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.cardPaperSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIconBox(
                icon: requiresTakeover
                    ? Icons.phonelink_setup_rounded
                    : Icons.phone_android_rounded,
              ),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.restoreConsequenceTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      requiresTakeover
                          ? l10n.restoreConsequenceTakeover
                          : l10n.restoreConsequenceSameDevice,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.compact),
          Container(
            key: const ValueKey('restore-previous-phone-pending-note'),
            width: double.infinity,
            padding: AppSpacing.authNotePadding,
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: AppSpacing.settingsOptionRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: AppSpacing.iconSmall,
                  color: context.colorScheme.onPrimaryContainer,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.restorePreviousPhonePendingWarning,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalLedgerCard extends StatelessWidget {
  const _LocalLedgerCard({required this.local});

  final RestoreLocalLedgerSummary local;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final captionStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Container(
      key: const ValueKey('restore-local-ledger-card'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.cardPaperSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: local.isPopulated
              ? context.appColors.creditColor
              : context.colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIconBox(
                icon: local.isPopulated
                    ? Icons.menu_book_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local.isPopulated
                          ? l10n.restoreLocalPopulatedTitle
                          : l10n.restoreLocalEmptyTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      local.isPopulated
                          ? l10n.restoreLocalPopulatedWarning
                          : l10n.restoreLocalEmptyMessage,
                      style: captionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (local.isPopulated) ...[
            SizedBox(height: AppSpacing.compact),
            Text(
              l10n.restoreCustomersCount(local.customerCount),
              style: captionStyle,
            ),
            Text(
              l10n.restoreTransactionsCount(local.transactionCount),
              style: captionStyle,
            ),
            if (local.deletedAndAuditCount > 0)
              Text(
                l10n.restoreHistoryCount(local.deletedAndAuditCount),
                style: captionStyle,
              ),
            Text(
              l10n.backupPendingChanges(local.pendingChangesCount),
              style: context.textTheme.bodySmall?.copyWith(
                color: local.hasPendingChanges
                    ? context.appColors.creditColor
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InterruptedTransferCard extends StatelessWidget {
  const _InterruptedTransferCard({required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();
    final transfer = state.pendingTransfer;
    final cloud = transfer?.cloudPreview ?? state.cloudPreview;

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
            onPressed: cubit == null
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
              onPressed: cubit == null
                  ? null
                  : () => unawaited(cubit.cancelInterruptedTransfer()),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestoreCompletedCard extends StatelessWidget {
  const _RestoreCompletedCard({required this.state});

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

class _RestoreNoticeCard extends StatelessWidget {
  const _RestoreNoticeCard({
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
