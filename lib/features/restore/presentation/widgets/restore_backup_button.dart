import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../screens/restore_screen.dart';

/// Outlined button on the Backup settings screen that opens the Cloud Restore
/// and Device Transfer flow.
class RestoreBackupButton extends StatelessWidget {
  const RestoreBackupButton({super.key, this.fullWidth = false});

  final bool fullWidth;

  @override
  Widget build(BuildContext context) => AppButton(
    key: const ValueKey('backup-restore'),
    label: context.l10n.backupRestoreAction,
    icon: Icons.cloud_download_outlined,
    variant: AppButtonVariant.outlined,
    fullWidth: fullWidth,
    onPressed: () {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        context.push(AppRoutes.settingsRestore);
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const RestoreScreen()));
      }
    },
  );
}
