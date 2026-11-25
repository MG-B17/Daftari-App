import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../restore/presentation/widgets/restore_backup_button.dart';
import '../models/backup_view_state.dart';
import '../widgets/backup_labels.dart';
import '../widgets/backup_now_button.dart';
import '../widgets/backup_schedule_section.dart';
import '../widgets/backup_status_card.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, this.state});

  final BackupViewState? state;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.backupScreenTitle,
    body: BackupViewStateBuilder(
      state: state,
      builder: (context, view) => ListView(
        children: [
          if (view.isPreview) ...[
            const BackupPreviewBanner(),
            SizedBox(height: AppSpacing.settingsSectionGap),
          ],
          BackupStatusCard(state: view),
          SizedBox(height: AppSpacing.settingsSectionGap),
          BackupNowButton(state: view, fullWidth: true),
          SizedBox(height: AppSpacing.compact),
          const RestoreBackupButton(fullWidth: true),
          SizedBox(height: AppSpacing.settingsSectionGap),
          BackupScheduleSection(
            initialSchedule: view.schedule,
            isPreview: view.isPreview,
          ),
        ],
      ),
    ),
  );
}
