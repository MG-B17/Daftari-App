import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/customers/presentation/screens/customer_form_screen.dart';
import '../../features/customers/presentation/screens/customer_details_screen.dart';
import '../../features/layout/presentation/screens/app_layout_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/local_storage_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_scaffold.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static GoRouter create({
    LocalStorageService? localStorage,
    OnboardingCubit Function()? createOnboardingCubit,
  }) => GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => SplashScreen(
          onFinished: () => context.go(
            localStorage != null && !localStorage.onboardingCompleted
                ? AppRoutes.onboarding
                : AppRoutes.root,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        redirect: (context, state) =>
            localStorage == null || localStorage.onboardingCompleted
            ? AppRoutes.root
            : null,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              createOnboardingCubit?.call() ?? OnboardingCubit(localStorage!),
          child: const OnboardingScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppLayoutScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.root,
                name: AppRoutes.rootName,
                builder: (context, state) {
                  final l10n = AppLocalizations.of(context)!;
                  return AppScaffold(
                    title: l10n.appTitle,
                    actions: [
                      IconButton(
                        key: const ValueKey('open-customers'),
                        tooltip: l10n.customersTitle,
                        onPressed: () => context.go(AppRoutes.customers),
                        icon: const Icon(Icons.people_outline),
                      ),
                      IconButton(
                        key: const ValueKey('open-settings'),
                        tooltip: l10n.settingsTitle,
                        onPressed: () => context.go(AppRoutes.settings),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
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
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                name: AppRoutes.customersName,
                builder: (context, state) => const CustomersListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.customerNew,
        name: AppRoutes.customerNewName,
        builder: (context, state) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerEdit,
        name: AppRoutes.customerEditName,
        builder: (context, state) =>
            CustomerFormScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.customerDetails,
        name: AppRoutes.customerDetailsName,
        builder: (context, state) =>
            CustomerDetailsScreen(customerId: state.pathParameters['id']!),
      ),
    ],
  );
}
