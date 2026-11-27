import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../models/backup_view_state.dart';
import 'backup_labels.dart';
import 'backup_now_button.dart';
import 'backup_status_pill.dart';

/// Settings entry for cloud backup: status, manual action and management.
class BackupSettingsSection extends StatelessWidget {
  const BackupSettingsSection({super.key, this.state});

  final BackupViewState? state;

  @override
  Widget build(BuildContext context) => BackupViewStateBuilder(
    state: state,
    builder: (context, view) {
      final l10n = context.l10n;
      return SettingsSectionCard(
        title: l10n.backupSectionTitle,
        child: Material(
          color: context.appColors.cardPaperSurface,
          child: Column(
            children: [
              if (view.isPreview) ...[
                const BackupPreviewBanner(),
                SizedBox(height: AppSpacing.compact),
              ],
              if (view.isRunning) ...[
                const LinearProgressIndicator(),
                SizedBox(height: AppSpacing.compact),
              ],
              _StatusRow(state: view),
              Divider(height: AppSpacing.lg),
              _BackupNowRow(state: view),
              Divider(height: AppSpacing.lg),
              ListTile(
                key: const ValueKey('backup-manage-tile'),
                contentPadding: EdgeInsets.zero,
                leading: const SettingsIconBox(
                  icon: Icons.drive_folder_upload_outlined,
                ),
                title: Text(l10n.backupManageTitle),
                subtitle: Text(l10n.backupManageSubtitle),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                ),
                onTap: () => context.push(AppRoutes.settingsBackup),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final BackupViewState state;

  @override
  Widget build(BuildContext context) {
    final captionStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    final failureText = state.failureHint(context);
    final inactiveText = state.inactiveDeviceHint(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsIconBox(icon: state.status.icon),
        SizedBox(width: AppSpacing.compact),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.l10n.backupSyncStatusTitle,
                    style: context.textTheme.titleMedium,
                  ),
                  BackupStatusPill(status: state.status),
                ],
              ),
              SizedBox(height: AppSpacing.xxs),
              Text(state.lastConfirmedLabel(context), style: captionStyle),
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
    );
  }
}

class _BackupNowRow extends StatelessWidget {
  const _BackupNowRow({required this.state});

  final BackupViewState state;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.backupNowTitle,
              style: context.textTheme.titleSmall,
            ),
            Text(
              context.l10n.backupNowSubtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: AppSpacing.compact),
      Flexible(child: BackupNowButton(state: state)),
    ],
  );
}
