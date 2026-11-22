import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/update_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
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
import '../../features/security/presentation/cubit/app_lock_cubit.dart';
import '../../features/security/domain/entities/pin_flow_mode.dart';
import '../../features/security/presentation/screens/pin_lock_screen.dart';
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
  static Listenable? _combineListenables(
    AppLockCubit? appLock,
    AuthCubit? authCubit,
  ) {
    if (appLock != null && authCubit != null) {
      return Listenable.merge([appLock, authCubit]);
    }
    return appLock ?? authCubit;
  }

  static GoRouter create({
    LocalStorageService? localStorage,
    OnboardingCubit Function()? createOnboardingCubit,
    AppLockCubit? appLock,
    AuthCubit? authCubit,
  }) => GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _combineListenables(appLock, authCubit),
    redirect: (context, state) {
      final path = state.uri.path;
      if (appLock != null) {
        if (!appLock.state.initialized) {
          return path == AppRoutes.splash ? null : AppRoutes.splash;
        }
        if (appLock.state.locked) {
          return path == AppRoutes.lock ? null : AppRoutes.lock;
        }
        if (path == AppRoutes.lock) {
          if (authCubit?.state.passwordRecoveryPending == true) {
            return AppRoutes.authUpdatePassword;
          }
          return localStorage != null && !localStorage.onboardingCompleted
              ? AppRoutes.onboarding
              : AppRoutes.root;
        }
        if (path == AppRoutes.settingsPin) {
          final mode = state.uri.queryParameters['mode'];
          if (mode == 'reset' ||
              mode == 'unlock' ||
              (mode == 'setup' && appLock.state.settings.isPinEnabled) ||
              ((mode == 'change' || mode == 'disable') &&
                  !appLock.state.settings.isPinEnabled)) {
            return AppRoutes.settings;
          }
        }
      }
      if (authCubit != null && authCubit.state.passwordRecoveryPending) {
        if (path != AppRoutes.authUpdatePassword && path != AppRoutes.splash) {
          return AppRoutes.authUpdatePassword;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.lock,
        name: AppRoutes.lockName,
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const PinLockScreen()),
      ),
      GoRoute(
        path: AppRoutes.settingsPin,
        name: AppRoutes.settingsPinName,
        pageBuilder: (context, state) {
          final mode = switch (state.uri.queryParameters['mode']) {
            'change' => PinFlowMode.change,
            'disable' => PinFlowMode.disable,
            _ => PinFlowMode.setup,
          };
          return FadeTransitionPage(
            key: state.pageKey,
            child: PinLockScreen(mode: mode),
          );
        },
      ),
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
      GoRoute(
        path: AppRoutes.authLogin,
        name: AppRoutes.authLoginName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.authRegister,
        name: AppRoutes.authRegisterName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.authForgotPassword,
        name: AppRoutes.authForgotPasswordName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.authVerifyEmail,
        name: AppRoutes.authVerifyEmailName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: VerifyEmailScreen(email: state.uri.queryParameters['email']),
        ),
      ),
      GoRoute(
        path: AppRoutes.authUpdatePassword,
        name: AppRoutes.authUpdatePasswordName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: const UpdatePasswordScreen(),
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
