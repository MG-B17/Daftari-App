import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.l10n.dashboardGreetingCaption),
      Text(context.l10n.dashboardWelcome, style: context.textTheme.titleLarge),
    ],
  );
}
