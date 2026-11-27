import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/forgot_password/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/login/presentation/cubit/login_cubit.dart';
import '../../features/auth/login/presentation/screens/login_screen.dart';
import '../../features/auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import '../../features/auth/sign_up/presentation/screens/register_screen.dart';
import '../../features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import '../../features/auth/update_password/presentation/screens/update_password_screen.dart';
import '../../features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import '../../features/auth/verify_email/presentation/screens/verify_email_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/restore/presentation/cubit/restore_cubit.dart';
import '../../features/restore/presentation/screens/restore_screen.dart';
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
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/security/presentation/cubit/app_lock_cubit.dart';
import '../../features/security/domain/entities/pin_flow_mode.dart';
import '../../features/security/presentation/screens/pin_lock_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/statements/presentation/screens/statement_screen.dart';
import '../../features/statements/presentation/cubit/statement_cubit.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../services/loacl_storage/local_storage_service.dart';
import '../animation/screen_transition_animation/fade_transition_page.dart';
import '../animation/screen_transition_animation/scale_transition_page.dart';
import '../animation/screen_transition_animation/slide_right_transition_page.dart';
import '../di/service_locator.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Listenable? _combineListenables(
    AppLockCubit? appLock,
    AuthSessionCubit? authSessionCubit,
  ) {
    if (appLock != null && authSessionCubit != null) {
      return Listenable.merge([appLock, authSessionCubit]);
    }
    return appLock ?? authSessionCubit;
  }

  static Widget _withOptionalCubit<T extends StateStreamableSource<Object?>>({
    required T Function()? factory,
    required Widget child,
  }) {
    final create = factory ?? (sl.isRegistered<T>() ? () => sl<T>() : null);
    if (create == null) return child;
    return BlocProvider<T>(create: (_) => create(), child: child);
  }

  static GoRouter create({
    LocalStorageService? localStorage,
    OnboardingCubit Function()? createOnboardingCubit,
    AppLockCubit? appLock,
    AuthSessionCubit? authSessionCubit,
    LoginCubit Function()? createLoginCubit,
    SignUpCubit Function()? createSignUpCubit,
    ForgotPasswordCubit Function()? createForgotPasswordCubit,
    VerifyEmailCubit Function()? createVerifyEmailCubit,
    UpdatePasswordCubit Function()? createUpdatePasswordCubit,
    RestoreCubit Function()? createRestoreCubit,
    SearchCubit Function()? createSearchCubit,
  }) => GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _combineListenables(appLock, authSessionCubit),
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
          if (authSessionCubit?.state.passwordRecoveryPending == true) {
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
      if (authSessionCubit != null &&
          authSessionCubit.state.passwordRecoveryPending) {
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
        path: AppRoutes.settingsBackup,
        name: AppRoutes.settingsBackupName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: const BackupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settingsRestore,
        name: AppRoutes.settingsRestoreName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: context.read<RestoreCubit?>() != null
              ? const RestoreScreen()
              : _withOptionalCubit<RestoreCubit>(
                  factory: createRestoreCubit,
                  child: const RestoreScreen(),
                ),
        ),
      ),
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        pageBuilder: (context, state) {
          void finishSplash() => context.go(
            localStorage != null && !localStorage.onboardingCompleted
                ? AppRoutes.onboarding
                : AppRoutes.root,
          );
          final child = appLock == null
              ? SplashScreen(onFinished: finishSplash)
              : ListenableBuilder(
                  listenable: appLock,
                  builder: (context, _) => SplashScreen(
                    hold: !appLock.state.initialized,
                    onFinished: finishSplash,
                  ),
                );
          return FadeTransitionPage(key: state.pageKey, child: child);
        },
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
          child: _withOptionalCubit<LoginCubit>(
            factory: createLoginCubit,
            child: const LoginScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.authRegister,
        name: AppRoutes.authRegisterName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: _withOptionalCubit<SignUpCubit>(
            factory: createSignUpCubit,
            child: const RegisterScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.authForgotPassword,
        name: AppRoutes.authForgotPasswordName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: _withOptionalCubit<ForgotPasswordCubit>(
            factory: createForgotPasswordCubit,
            child: const ForgotPasswordScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.authVerifyEmail,
        name: AppRoutes.authVerifyEmailName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: _withOptionalCubit<VerifyEmailCubit>(
            factory: createVerifyEmailCubit,
            child: VerifyEmailScreen(email: state.uri.queryParameters['email']),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.authUpdatePassword,
        name: AppRoutes.authUpdatePasswordName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: _withOptionalCubit<UpdatePasswordCubit>(
            factory: createUpdatePasswordCubit,
            child: const UpdatePasswordScreen(),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => FadeTransitionPage(
          key: state.pageKey,
          child: AppLayoutScreen(navigationShell: navigationShell),
        ),
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
        path: AppRoutes.search,
        name: AppRoutes.searchName,
        pageBuilder: (context, state) => SlideRightTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) =>
                (createSearchCubit?.call() ?? sl<SearchCubit>())..load(),
            child: const SearchScreen(),
          ),
        ),
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
