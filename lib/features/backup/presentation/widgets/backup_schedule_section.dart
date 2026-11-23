import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../models/backup_view_state.dart';
import 'backup_schedule_selector.dart';

/// Manages local schedule selection until Task 4 connects [BackupCubit].
class BackupScheduleSection extends StatefulWidget {
  const BackupScheduleSection({super.key, this.initialSchedule});

  final BackupSchedule? initialSchedule;

  @override
  State<BackupScheduleSection> createState() => _BackupScheduleSectionState();
}

class _BackupScheduleSectionState extends State<BackupScheduleSection> {
  late BackupSchedule? _selected = widget.initialSchedule;

  @override
  void didUpdateWidget(covariant BackupScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSchedule != oldWidget.initialSchedule) {
      _selected = widget.initialSchedule;
    }
  }

  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    title: context.l10n.backupScheduleTitle,
    child: BackupScheduleSelector(
      selected: _selected,
      onSelected: (schedule) => setState(() => _selected = schedule),
    ),
  );
}
