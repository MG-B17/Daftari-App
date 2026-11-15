import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_scaffold.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static GoRouter create() => GoRouter(
    initialLocation: AppRoutes.root,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        name: AppRoutes.rootName,
        builder: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          return AppScaffold(
            title: l10n.appTitle,
            body: Center(
              child: AppEmptyState(
                icon: Icons.menu_book_rounded,
                title: l10n.foundationReady,
                message: l10n.foundationDescription,
              ),
            ),
          );
        },
      ),
    ],
  );
}
