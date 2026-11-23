import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/backup_view_state.dart';
import 'backup_account_card.dart';
import 'backup_labels.dart';
import 'backup_status_pill.dart';

class BackupStatusCard extends StatelessWidget {
  const BackupStatusCard({super.key, required this.state});

  final BackupViewState state;

  @override
  Widget build(BuildContext context) {
    final captionStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Container(
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
          if (state.isRunning) ...[
            const LinearProgressIndicator(),
            SizedBox(height: AppSpacing.compact),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(status: state.status),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BackupStatusPill(status: state.status),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      state.lastConfirmedLabel(context),
                      style: context.textTheme.titleLarge,
                    ),
                    Text(state.pendingLabel(context), style: captionStyle),
                    if (state.status == BackupStatus.failed)
                      Text(
                        context.l10n.backupFailedHint,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.appColors.creditColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          BackupAccountCard(
            shopName: state.accountShopName,
            email: state.accountEmail,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = status.colors(context);
    return Container(
      width: AppSpacing.settingsBadgeSize,
      height: AppSpacing.settingsBadgeSize,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: status == BackupStatus.running
          ? SizedBox.square(
              dimension: AppSpacing.iconMedium,
              child: CircularProgressIndicator(
                strokeWidth: AppSpacing.progressStroke,
                color: foreground,
              ),
            )
          : Icon(
              status == BackupStatus.upToDate
                  ? Icons.check_circle_rounded
                  : status.icon,
              size: AppSpacing.iconMedium,
              color: foreground,
            ),
    );
  }
}
