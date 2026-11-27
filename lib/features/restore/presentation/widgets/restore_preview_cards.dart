import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../domain/entities/restore_entities.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';
import 'restore_confirmation_cards.dart';
import 'restore_labels.dart';

/// Displays the confirmed cloud snapshot summary, the consequence for this
/// phone (including the warning that changes still pending on the previous
/// phone remain only there), the current local ledger summary, and the active
/// primary or replacement confirmation step.
class RestorePreviewAndConsentSection extends StatelessWidget {
  const RestorePreviewAndConsentSection({super.key, required this.state});

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
          RestoreRefreshReasonBanner(reason: reason),
          SizedBox(height: AppSpacing.compact),
        ],
        if (isExecuting) ...[
          const LinearProgressIndicator(
            key: ValueKey('restore-executing-progress'),
          ),
          SizedBox(height: AppSpacing.compact),
        ],
        if (cloud != null) ...[
          RestoreCloudSnapshotCard(cloud: cloud),
          SizedBox(height: AppSpacing.settingsSectionGap),
        ],
        RestoreConsequenceCard(requiresTakeover: state.requiresTakeover),
        SizedBox(height: AppSpacing.settingsSectionGap),
        if (local != null) ...[
          RestoreLocalLedgerCard(local: local),
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

class RestoreRefreshReasonBanner extends StatelessWidget {
  const RestoreRefreshReasonBanner({super.key, required this.reason});

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

class RestoreCloudSnapshotCard extends StatelessWidget {
  const RestoreCloudSnapshotCard({super.key, required this.cloud});

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

class RestoreConsequenceCard extends StatelessWidget {
  const RestoreConsequenceCard({super.key, required this.requiresTakeover});

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

class RestoreLocalLedgerCard extends StatelessWidget {
  const RestoreLocalLedgerCard({super.key, required this.local});

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
