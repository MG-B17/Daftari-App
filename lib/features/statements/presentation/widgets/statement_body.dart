import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'statement_actions_section.dart';
import 'statement_preview_card.dart';

class StatementBody extends StatelessWidget {
  const StatementBody({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: AppSpacing.statementMaxWidth),
      child: SingleChildScrollView(
        key: const ValueKey('statement-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: AppSpacing.pagePadding,
              decoration: BoxDecoration(
                color: context.appColors.customersAccentSurface,
                borderRadius: AppSpacing.borderRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: context.colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.compact),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.statementPreviewTitle,
                          style: context.textTheme.titleSmall,
                        ),
                        Text(
                          context.l10n.statementPreviewSubtitle,
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.compact),
            Text(
              context.l10n.statementMockNotice,
              key: const ValueKey('statement-mock-notice'),
              style: context.textTheme.bodySmall,
            ),
            SizedBox(height: AppSpacing.compact),
            const StatementPreviewCard(),
            SizedBox(height: AppSpacing.compact),
            const StatementActionsSection(),
          ],
        ),
      ),
    ),
  );
}
