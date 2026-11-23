import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/backup_view_state.dart';
import 'backup_labels.dart';

class BackupStatusPill extends StatelessWidget {
  const BackupStatusPill({super.key, required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = status.colors(context);
    return Container(
      key: ValueKey('backup-status-${status.name}'),
      padding: AppSpacing.badgePadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.tight,
            height: AppSpacing.tight,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              status.label(context),
              style: context.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
