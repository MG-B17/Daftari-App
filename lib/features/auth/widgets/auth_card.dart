import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.authCardPadding,
    decoration: BoxDecoration(
      color: context.appColors.cardPaperSurface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: context.colorScheme.outline),
    ),
    child: child,
  );
}
