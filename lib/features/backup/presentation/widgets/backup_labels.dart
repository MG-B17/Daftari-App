import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../../auth/session/presentation/cubit/auth_session_state.dart';
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

  String? failureHint(BuildContext context) {
    if (status != BackupStatus.failed) return null;
    return lastConfirmedAt == null
        ? context.l10n.backupFailedFirstHint
        : context.l10n.backupFailedHint;
  }
}

/// Resolves an explicit [state] or falls back to an accurate preview state
/// reflecting the current [AuthSessionCubit] account when available.
class BackupViewStateBuilder extends StatelessWidget {
  const BackupViewStateBuilder({
    super.key,
    required this.state,
    required this.builder,
  });

  final BackupViewState? state;
  final Widget Function(BuildContext context, BackupViewState view) builder;

  @override
  Widget build(BuildContext context) {
    if (state case final fixed?) return builder(context, fixed);
    final authCubit = context.read<AuthSessionCubit?>();
    if (authCubit == null) {
      return builder(context, BackupViewState.preview());
    }
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      builder: (context, authState) => builder(
        context,
        BackupViewState.preview(
          user: authState.isAuthenticated ? authState.user : null,
        ),
      ),
    );
  }
}

class BackupPreviewBanner extends StatelessWidget {
  const BackupPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      key: const ValueKey('backup-preview-banner'),
      width: double.infinity,
      padding: AppSpacing.authNotePadding,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: AppSpacing.settingsOptionRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppSpacing.iconSmall,
            color: colors.onPrimaryContainer,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.backupPreviewBanner,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showBackupMockNotice(BuildContext context) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(context.l10n.backupMockNotice)));
