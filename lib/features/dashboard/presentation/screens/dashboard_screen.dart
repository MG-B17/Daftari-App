import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/dashboard_body.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.dashboardTitle,
    subtitle: context.l10n.dashboardSubtitle,
    padding: EdgeInsets.zero,
    actions: [
      IconButton(
        key: const ValueKey('dashboard-search'),
        tooltip: context.l10n.customersTitle,
        onPressed: () => context.go(AppRoutes.customers),
        icon: const Icon(Icons.search),
      ),
    ],
    body: const DashboardBody(),
  );
}
