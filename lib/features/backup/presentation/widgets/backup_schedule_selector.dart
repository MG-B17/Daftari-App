import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/backup_view_state.dart';

class BackupScheduleSelector extends StatelessWidget {
  const BackupScheduleSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// `null` until the user explicitly chooses the first schedule.
  final BackupSchedule? selected;
  final ValueChanged<BackupSchedule> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final schedule in BackupSchedule.values) ...[
                if (schedule != BackupSchedule.values.first)
                  SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ScheduleOptionCard(
                    schedule: schedule,
                    label: switch (schedule) {
                      BackupSchedule.daily => l10n.backupScheduleDaily,
                      BackupSchedule.weekly => l10n.backupScheduleWeekly,
                      BackupSchedule.monthly => l10n.backupScheduleMonthly,
                    },
                    icon: switch (schedule) {
                      BackupSchedule.daily => Icons.today_outlined,
                      BackupSchedule.weekly => Icons.date_range_outlined,
                      BackupSchedule.monthly => Icons.calendar_month_outlined,
                    },
                    isSelected: selected == schedule,
                    onTap: () => onSelected(schedule),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: AppSpacing.compact),
        Text(
          l10n.backupScheduleCaption,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ScheduleOptionCard extends StatelessWidget {
  const _ScheduleOptionCard({
    required this.schedule,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final BackupSchedule schedule;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final foreground = isSelected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.primary : context.appColors.cardPaperSurface,
        borderRadius: AppSpacing.settingsOptionRadius,
        child: InkWell(
          key: ValueKey('backup-schedule-${schedule.name}'),
          onTap: onTap,
          borderRadius: AppSpacing.settingsOptionRadius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: AppSpacing.settingsOptionHeight,
            ),
            padding: AppSpacing.settingsOptionPadding,
            decoration: BoxDecoration(
              borderRadius: AppSpacing.settingsOptionRadius,
              border: Border.all(
                color: isSelected ? colors.primary : colors.outline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppSpacing.iconMedium, color: foreground),
                SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
