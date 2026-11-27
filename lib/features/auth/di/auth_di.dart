import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/session_commit_gate/session_commit_gate.dart';
import '../forgot_password/data/repositories/forgot_password_repository_impl.dart';
import '../forgot_password/domain/repositories/forgot_password_repository.dart';
import '../forgot_password/domain/usecases/send_password_reset_usecase.dart';
import '../forgot_password/presentation/cubit/forgot_password_cubit.dart';
import '../login/data/repositories/login_repository_impl.dart';
import '../login/domain/repositories/login_repository.dart';
import '../login/domain/usecases/sign_in_usecase.dart';
import '../login/presentation/cubit/login_cubit.dart';
import '../session/data/repositories/auth_session_repository_impl.dart';
import '../session/data/services/auth_error_mapper.dart';
import '../session/data/services/ledger_owner_storage.dart';
import '../session/data/services/supabase_auth_service.dart';
import '../session/data/services/supabase_bootstrap.dart';
import '../session/domain/repositories/auth_session_coordinator.dart';
import '../session/domain/repositories/auth_session_repository.dart';
import '../session/domain/usecases/confirm_ledger_link_usecase.dart';
import '../session/domain/usecases/sign_out_usecase.dart';
import '../session/presentation/cubit/auth_session_cubit.dart';
import '../sign_up/data/repositories/sign_up_repository_impl.dart';
import '../sign_up/domain/repositories/sign_up_repository.dart';
import '../sign_up/domain/usecases/sign_up_usecase.dart';
import '../sign_up/presentation/cubit/sign_up_cubit.dart';
import '../update_password/data/repositories/update_password_repository_impl.dart';
import '../update_password/domain/repositories/update_password_repository.dart';
import '../update_password/domain/usecases/update_password_usecase.dart';
import '../update_password/presentation/cubit/update_password_cubit.dart';
import '../verify_email/data/repositories/verify_email_repository_impl.dart';
import '../verify_email/domain/repositories/verify_email_repository.dart';
import '../verify_email/domain/usecases/check_email_verified_usecase.dart';
import '../verify_email/domain/usecases/resend_verification_email_usecase.dart';
import '../verify_email/presentation/cubit/verify_email_cubit.dart';

void registerAuthDependencies(GetIt sl) {
  if (!sl.isRegistered<SupabaseBootstrap>()) {
    sl.registerLazySingleton<SupabaseBootstrap>(SupabaseBootstrap.new);
  }
  if (!sl.isRegistered<LedgerOwnerStorage>()) {
    sl.registerLazySingleton<LedgerOwnerStorage>(
      () => LedgerOwnerStorage(
        sl<FlutterSecureStorage>(),
        readDurableOwnerId: () => sl<BackupDao>().readDurableOwnerId(),
        claimDurableOwnerId: (ownerUserId) =>
            sl<BackupDao>().claimOrReadDurableOwnerId(ownerUserId),
      ),
    );
  }
  if (!sl.isRegistered<AuthService>()) {
    sl.registerLazySingleton<AuthService>(
      () => SupabaseAuthService(
        sl<SupabaseBootstrap>(),
        commitGate: sl<SessionCommitGate>(),
      ),
    );
  }
  if (!sl.isRegistered<AuthErrorMapper>()) {
    sl.registerLazySingleton<AuthErrorMapper>(
      () => AuthErrorMapper(sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<AuthSessionRepository>()) {
    sl.registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl(
        sl<AuthService>(),
        sl<LedgerOwnerStorage>(),
        () => sl<CustomerDao>().hasAnyCustomers(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<SignOutUseCase>()) {
    sl.registerLazySingleton<SignOutUseCase>(
      () => SignOutUseCase(sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<ConfirmLedgerLinkUseCase>()) {
    sl.registerLazySingleton<ConfirmLedgerLinkUseCase>(
      () => ConfirmLedgerLinkUseCase(sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<AuthSessionCubit>()) {
    sl.registerLazySingleton<AuthSessionCubit>(
      () => AuthSessionCubit(
        sl<AuthSessionRepository>(),
        sl<SignOutUseCase>(),
        sl<ConfirmLedgerLinkUseCase>(),
      ),
      dispose: (cubit) => cubit.close(),
    );
  }
  if (!sl.isRegistered<AuthSessionCoordinator>()) {
    sl.registerLazySingleton<AuthSessionCoordinator>(
      () => sl<AuthSessionCubit>(),
    );
  }
  if (!sl.isRegistered<LoginRepository>()) {
    sl.registerLazySingleton<LoginRepository>(
      () => LoginRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<SignInUseCase>()) {
    sl.registerLazySingleton<SignInUseCase>(
      () => SignInUseCase(sl<LoginRepository>(), sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<LoginCubit>()) {
    sl.registerFactory<LoginCubit>(
      () => LoginCubit(sl<SignInUseCase>(), sl<AuthSessionCoordinator>()),
    );
  }
  if (!sl.isRegistered<SignUpRepository>()) {
    sl.registerLazySingleton<SignUpRepository>(
      () => SignUpRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<SignUpUseCase>()) {
    sl.registerLazySingleton<SignUpUseCase>(
      () => SignUpUseCase(sl<SignUpRepository>(), sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<SignUpCubit>()) {
    sl.registerFactory<SignUpCubit>(
      () => SignUpCubit(sl<SignUpUseCase>(), sl<AuthSessionCoordinator>()),
    );
  }
  if (!sl.isRegistered<ForgotPasswordRepository>()) {
    sl.registerLazySingleton<ForgotPasswordRepository>(
      () => ForgotPasswordRepositoryImpl(
        sl<AuthService>(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<SendPasswordResetUseCase>()) {
    sl.registerLazySingleton<SendPasswordResetUseCase>(
      () => SendPasswordResetUseCase(sl<ForgotPasswordRepository>()),
    );
  }
  if (!sl.isRegistered<ForgotPasswordCubit>()) {
    sl.registerFactory<ForgotPasswordCubit>(
      () => ForgotPasswordCubit(
        sl<SendPasswordResetUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
  if (!sl.isRegistered<VerifyEmailRepository>()) {
    sl.registerLazySingleton<VerifyEmailRepository>(
      () => VerifyEmailRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<ResendVerificationEmailUseCase>()) {
    sl.registerLazySingleton<ResendVerificationEmailUseCase>(
      () => ResendVerificationEmailUseCase(sl<VerifyEmailRepository>()),
    );
  }
  if (!sl.isRegistered<CheckEmailVerifiedUseCase>()) {
    sl.registerLazySingleton<CheckEmailVerifiedUseCase>(
      () => CheckEmailVerifiedUseCase(
        sl<VerifyEmailRepository>(),
        sl<AuthSessionRepository>(),
      ),
    );
  }
  if (!sl.isRegistered<VerifyEmailCubit>()) {
    sl.registerFactory<VerifyEmailCubit>(
      () => VerifyEmailCubit(
        sl<ResendVerificationEmailUseCase>(),
        sl<CheckEmailVerifiedUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
  if (!sl.isRegistered<UpdatePasswordRepository>()) {
    sl.registerLazySingleton<UpdatePasswordRepository>(
      () => UpdatePasswordRepositoryImpl(
        sl<AuthService>(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<UpdatePasswordUseCase>()) {
    sl.registerLazySingleton<UpdatePasswordUseCase>(
      () => UpdatePasswordUseCase(sl<UpdatePasswordRepository>()),
    );
  }
  if (!sl.isRegistered<UpdatePasswordCubit>()) {
    sl.registerFactory<UpdatePasswordCubit>(
      () => UpdatePasswordCubit(
        sl<UpdatePasswordUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
}
