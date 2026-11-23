import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../models/backup_view_state.dart';
import 'backup_labels.dart';

class BackupNowButton extends StatelessWidget {
  const BackupNowButton({
    super.key,
    required this.state,
    this.fullWidth = false,
  });

  final BackupViewState state;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => AppButton(
    key: const ValueKey('backup-now'),
    label: context.l10n.backupNowAction,
    icon: Icons.cloud_upload_outlined,
    fullWidth: fullWidth,
    isLoading: state.isRunning,
    onPressed: state.canBackUpNow ? () => showBackupMockNotice(context) : null,
  );
}
