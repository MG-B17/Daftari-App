import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/restore_entities.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';
import 'restore_labels.dart';

/// First confirmation card: confirms combined restore and device authority
/// transfer on a new phone, or confirms restore without authority change on the
/// existing active backup phone.
class RestorePrimaryConfirmationCard extends StatelessWidget {
  const RestorePrimaryConfirmationCard({super.key, required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();
    final requiresTakeover = state.requiresTakeover;
    final cloud = state.cloudPreview;
    final title = requiresTakeover
        ? l10n.restoreConfirmTakeoverTitle
        : l10n.restoreConfirmSameDeviceTitle;
    final message = requiresTakeover
        ? l10n.restoreConfirmTakeoverMessage
        : l10n.restoreConfirmSameDeviceMessage;
    final confirmLabel = requiresTakeover
        ? l10n.restoreConfirmTakeoverButton
        : l10n.restoreConfirmSameDeviceButton;

    return Container(
      key: const ValueKey('restore-primary-confirmation'),
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
              Icon(
                requiresTakeover
                    ? Icons.phonelink_setup_rounded
                    : Icons.cloud_download_outlined,
                color: context.colorScheme.primary,
                size: AppSpacing.iconMedium,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: context.textTheme.titleMedium),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          if (cloud != null) ...[
            Text(
              cloud.confirmedAt.confirmedAtLabel(context),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
          ],
          Text(message, style: context.textTheme.bodyMedium),
          SizedBox(height: AppSpacing.md),
          AppButton(
            key: const ValueKey('restore-primary-confirm'),
            label: confirmLabel,
            icon: Icons.check_circle_outline_rounded,
            fullWidth: true,
            onPressed: cubit == null
                ? null
                : () => unawaited(cubit.confirmPrimary()),
          ),
          SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const ValueKey('restore-primary-cancel'),
            label: l10n.cancel,
            variant: AppButtonVariant.outlined,
            fullWidth: true,
            onPressed: cubit?.cancelConfirmation,
          ),
        ],
      ),
    );
  }
}

/// Second explicit confirmation card required before replacing a populated
/// local ledger linked to the same account, displaying local record counts and
/// local pending changes that will be replaced.
class RestoreReplacementConfirmationCard extends StatelessWidget {
  const RestoreReplacementConfirmationCard({super.key, required this.state});

  final RestoreViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RestoreCubit?>();
    final local =
        state.localLedger ??
        const RestoreLocalLedgerSummary(deviceId: 'preview-device');

    return Container(
      key: const ValueKey('restore-replacement-confirmation'),
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.creditSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: context.appColors.creditColor,
          width: AppSpacing.selectedStroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: context.appColors.creditColor,
                size: AppSpacing.iconMedium,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.restoreReplacementConfirmTitle,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.appColors.creditColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            l10n.restoreReplacementConfirmMessage,
            style: context.textTheme.bodyMedium,
          ),
          SizedBox(height: AppSpacing.compact),
          Container(
            key: const ValueKey('restore-replacement-local-counts'),
            width: double.infinity,
            padding: AppSpacing.authNotePadding,
            decoration: BoxDecoration(
              color: context.appColors.cardPaperSurface,
              borderRadius: AppSpacing.settingsOptionRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.restoreReplacementLocalSummaryTitle,
                  style: context.textTheme.labelLarge,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.restoreCustomersCount(local.customerCount),
                  style: context.textTheme.bodySmall,
                ),
                Text(
                  l10n.restoreTransactionsCount(local.transactionCount),
                  style: context.textTheme.bodySmall,
                ),
                if (local.deletedAndAuditCount > 0)
                  Text(
                    l10n.restoreHistoryCount(local.deletedAndAuditCount),
                    style: context.textTheme.bodySmall,
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
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppButton(
            key: const ValueKey('restore-replacement-confirm'),
            label: l10n.restoreReplacementConfirmButton,
            variant: AppButtonVariant.danger,
            icon: Icons.published_with_changes_rounded,
            fullWidth: true,
            onPressed: cubit == null
                ? null
                : () => unawaited(cubit.confirmReplacement()),
          ),
          SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const ValueKey('restore-replacement-cancel'),
            label: l10n.cancel,
            variant: AppButtonVariant.outlined,
            fullWidth: true,
            onPressed: cubit?.cancelConfirmation,
          ),
        ],
      ),
    );
  }
}
