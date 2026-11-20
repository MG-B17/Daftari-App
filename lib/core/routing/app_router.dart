import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/customers/domain/entities/picked_contact.dart';
import '../../features/customers/presentation/cubit/customer_details_cubit.dart';
import '../../features/customers/presentation/cubit/customer_form_cubit.dart';
import '../../features/customers/presentation/cubit/customers_list_cubit.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/customers/presentation/screens/customer_form_screen.dart';
import '../../features/customers/presentation/screens/customer_details_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/layout/presentation/screens/app_layout_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/statements/presentation/screens/statement_screen.dart';
import '../../features/statements/presentation/cubit/statement_cubit.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../services/local_storage_service.dart';
import '../animation/screen_transition_animation/fade_transition_page.dart';
import '../animation/screen_transition_animation/scale_transition_page.dart';
import '../animation/screen_transition_animation/slide_right_transition_page.dart';
import '../di/service_locator.dart';
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
        pageBuilder: (context, state) => FadeTransitionPage(
          key: state.pageKey,
          child: SplashScreen(
            onFinished: () => context.go(
              localStorage != null && !localStorage.onboardingCompleted
                  ? AppRoutes.onboarding
                  : AppRoutes.root,
            ),
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
        pageBuilder: (context, state) => FadeTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) =>
                createOnboardingCubit?.call() ?? OnboardingCubit(localStorage!),
            child: const OnboardingScreen(),
          ),
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
                pageBuilder: (context, state) => FadeTransitionPage(
                  key: state.pageKey,
                  child: BlocProvider(
                    create: (_) => sl<DashboardCubit>()..refresh(),
                    child: const DashboardScreen(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                name: AppRoutes.customersName,
                pageBuilder: (context, state) => FadeTransitionPage(
                  key: state.pageKey,
                  child: BlocProvider(
                    create: (_) => sl<CustomersListCubit>()..load(),
                    child: const CustomersListScreen(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                pageBuilder: (context, state) => FadeTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.transactionNew,
        name: AppRoutes.transactionNewName,
        pageBuilder: (context, state) => ScaleTransitionPage(
          key: state.pageKey,
          child: TransactionFormScreen(
            customerId: state.uri.queryParameters['customerId'],
            initialType: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.transactionEdit,
        name: AppRoutes.transactionEditName,
        pageBuilder: (context, state) => ScaleTransitionPage(
          key: state.pageKey,
          child: TransactionFormScreen(
            transactionId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerNew,
        name: AppRoutes.customerNewName,
        pageBuilder: (context, state) => ScaleTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) => sl<CustomerFormCubit>(),
            child: CustomerFormScreen(
              initialContact: state.extra is PickedContact
                  ? state.extra as PickedContact
                  : null,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerEdit,
        name: AppRoutes.customerEditName,
        pageBuilder: (context, state) => ScaleTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) =>
                sl<CustomerFormCubit>()..load(state.pathParameters['id']!),
            child: CustomerFormScreen(customerId: state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerStatement,
        name: AppRoutes.customerStatementName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) =>
                sl<StatementCubit>()..load(state.pathParameters['id']!),
            child: StatementScreen(customerId: state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerDetails,
        name: AppRoutes.customerDetailsName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) =>
                sl<CustomerDetailsCubit>()..load(state.pathParameters['id']!),
            child: CustomerDetailsScreen(
              customerId: state.pathParameters['id']!,
            ),
          ),
        ),
      ),
    ],
  );
}
