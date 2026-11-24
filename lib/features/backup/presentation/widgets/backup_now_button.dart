import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/backup_cubit.dart';
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
  Widget build(BuildContext context) {
    final backupCubit = context.read<BackupCubit?>();
    return AppButton(
      key: const ValueKey('backup-now'),
      label: context.l10n.backupNowAction,
      icon: Icons.cloud_upload_outlined,
      fullWidth: fullWidth,
      isLoading: state.isRunning,
      onPressed: state.canBackUpNow
          ? () {
              if (backupCubit != null && !state.isPreview) {
                unawaited(backupCubit.backUpNow());
              } else {
                showBackupMockNotice(context);
              }
            }
          : null,
    );
  }
}
