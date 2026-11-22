import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../auth/widgets/auth_feedback_mapper.dart';
import '../widgets/liquid_navigation_bar.dart';

class AppLayoutScreen extends StatelessWidget {
  const AppLayoutScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => AuthFlowListener(
    navigateOnVerifyEmail: false,
    popOnAuthenticated: false,
    child: Scaffold(
      body: navigationShell,
      bottomNavigationBar: LiquidNavigationBar(
        items: [
          LiquidNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: context.l10n.customersHome,
          ),
          LiquidNavItem(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: context.l10n.customersTitle,
          ),
          LiquidNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: context.l10n.settingsTitle,
          ),
        ],
        backgroundColor: context.appColors.cardPaperSurface,
        indicatorColor: context.appColors.customersAccentSurface,
        selectedColor: context.colorScheme.primary,
        unselectedColor: context.colorScheme.onSurface,
        selectedIndex: navigationShell.currentIndex,
        onSelected: navigationShell.goBranch,
      ),
    ),
  );
}
