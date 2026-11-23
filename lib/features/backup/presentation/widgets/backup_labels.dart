import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../models/backup_view_state.dart';

extension BackupStatusLabels on BackupStatus {
  String label(BuildContext context) => switch (this) {
    BackupStatus.neverBackedUp => context.l10n.backupStatusNeverBackedUp,
    BackupStatus.pending => context.l10n.backupStatusPending,
    BackupStatus.running => context.l10n.backupStatusRunning,
    BackupStatus.failed => context.l10n.backupStatusFailed,
    BackupStatus.upToDate => context.l10n.backupStatusUpToDate,
  };

  IconData get icon => switch (this) {
    BackupStatus.neverBackedUp => Icons.cloud_off_outlined,
    BackupStatus.pending => Icons.cloud_upload_outlined,
    BackupStatus.running => Icons.cloud_sync_outlined,
    BackupStatus.failed => Icons.error_outline_rounded,
    BackupStatus.upToDate => Icons.cloud_done_outlined,
  };

  /// Background and foreground colors for status pills and badges.
  (Color, Color) colors(BuildContext context) => switch (this) {
    BackupStatus.upToDate => (
      context.appColors.paymentSurface,
      context.appColors.paymentColor,
    ),
    BackupStatus.failed => (
      context.appColors.creditSurface,
      context.appColors.creditColor,
    ),
    BackupStatus.neverBackedUp ||
    BackupStatus.pending ||
    BackupStatus.running => (
      context.colorScheme.primaryContainer,
      context.colorScheme.onPrimaryContainer,
    ),
  };
}

extension BackupViewStateLabels on BackupViewState {
  String lastConfirmedLabel(BuildContext context) {
    final confirmedAt = lastConfirmedAt;
    if (confirmedAt == null) return context.l10n.backupNeverConfirmed;
    final locale = Localizations.localeOf(context).languageCode;
    return context.l10n
        .backupLastConfirmed(
          AppDateUtils.relativeDay(confirmedAt, locale: locale),
          AppDateUtils.formatTime(confirmedAt, locale: locale),
        )
        .toWesternDigits;
  }

  String pendingLabel(BuildContext context) =>
      context.l10n.backupPendingChanges(pendingChanges);
}

void showBackupMockNotice(BuildContext context) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(context.l10n.backupMockNotice)));
