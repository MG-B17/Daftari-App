import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/daftari_loading.dart';
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
    final failureText = state.failureHint(context);
    final inactiveText = state.inactiveDeviceHint(context);
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
                    if (failureText != null)
                      Text(
                        failureText,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.appColors.creditColor,
                        ),
                      ),
                    if (inactiveText != null)
                      Text(
                        inactiveText,
                        key: const ValueKey('backup-inactive-device-hint'),
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
          ? DaftariLoading.inline(
              size: AppSpacing.iconMedium,
              color: foreground,
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
