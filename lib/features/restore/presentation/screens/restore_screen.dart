import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../backup/presentation/widgets/backup_account_card.dart';
import '../../../backup/presentation/widgets/backup_labels.dart';
import '../cubit/restore_state.dart';
import '../widgets/restore_labels.dart';
import '../widgets/restore_status_cards.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key, this.state});

  final RestoreViewState? state;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.restoreScreenTitle,
    body: RestoreViewStateBuilder(
      state: state,
      builder: (context, view) => ListView(
        children: [
          if (view.isPreview) ...[
            const BackupPreviewBanner(),
            SizedBox(height: AppSpacing.settingsSectionGap),
          ],
          BackupAccountCard(
            shopName: view.accountShopName,
            email: view.accountEmail,
          ),
          SizedBox(height: AppSpacing.settingsSectionGap),
          RestoreBodySection(state: view),
        ],
      ),
    ),
  );
}
