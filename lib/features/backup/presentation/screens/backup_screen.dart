import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../models/backup_view_state.dart';
import '../widgets/backup_labels.dart';
import '../widgets/backup_now_button.dart';
import '../widgets/backup_schedule_selector.dart';
import '../widgets/backup_status_card.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, this.state});

  final BackupViewState? state;

  @override
  Widget build(BuildContext context) {
    final view = state ?? BackupViewState.mock;
    return AppScaffold(
      title: context.l10n.backupScreenTitle,
      body: ListView(
        children: [
          BackupStatusCard(state: view),
          SizedBox(height: AppSpacing.settingsSectionGap),
          BackupNowButton(state: view, fullWidth: true),
          SizedBox(height: AppSpacing.settingsSectionGap),
          SettingsSectionCard(
            title: context.l10n.backupScheduleTitle,
            child: BackupScheduleSelector(
              selected: view.schedule,
              onSelected: (_) => showBackupMockNotice(context),
            ),
          ),
        ],
      ),
    );
  }
}
