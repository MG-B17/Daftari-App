import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_spacing.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.icon,
    child: CircularProgressIndicator(
      color: color,
      strokeWidth: 2,
      semanticsLabel: AppLocalizations.of(context)!.loading,
    ),
  );
}
