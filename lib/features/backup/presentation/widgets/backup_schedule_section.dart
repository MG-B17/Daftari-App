import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../cubit/backup_cubit.dart';
import '../models/backup_view_state.dart';
import 'backup_schedule_selector.dart';

/// Connects schedule selection to [BackupCubit] when mounted, falling back to
/// local selection state for isolated preview/fixture widget tests.
class BackupScheduleSection extends StatefulWidget {
  const BackupScheduleSection({
    super.key,
    this.initialSchedule,
    this.isPreview = false,
  });

  final BackupSchedule? initialSchedule;
  final bool isPreview;

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
  Widget build(BuildContext context) {
    final backupCubit = context.read<BackupCubit?>();
    final useLiveCubit = backupCubit != null && !widget.isPreview;
    return SettingsSectionCard(
      title: context.l10n.backupScheduleTitle,
      child: BackupScheduleSelector(
        selected: useLiveCubit ? widget.initialSchedule : _selected,
        onSelected: (schedule) {
          if (useLiveCubit) {
            unawaited(backupCubit.selectSchedule(schedule));
          } else {
            setState(() => _selected = schedule);
          }
        },
      ),
    );
  }
}
