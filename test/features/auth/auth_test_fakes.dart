import 'dart:async';

import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/features/auth/forgot_password/domain/repositories/forgot_password_repository.dart';
import 'package:daftariapp/features/auth/login/domain/repositories/login_repository.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/session/domain/repositories/auth_session_repository.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/sign_out_usecase.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/sign_up/domain/repositories/sign_up_repository.dart';
import 'package:daftariapp/features/auth/update_password/domain/repositories/update_password_repository.dart';
import 'package:daftariapp/features/auth/verify_email/domain/repositories/verify_email_repository.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const testUserA = AuthUser(
  id: 'user-a',
  email: 'owner@shop.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

const testUserB = AuthUser(
  id: 'user-b',
  email: 'other@shop.com',
  shopName: 'Other Shop',
  emailVerified: true,
);

const testUnverifiedUser = AuthUser(
  id: 'user-c',
  email: 'pending@shop.com',
  shopName: 'Pending Shop',
  emailVerified: false,
);

const testValidationFailure = AppFailure(AppErrorCode.validation);
const testAuthFailure = AppFailure(AppErrorCode.auth);
const testStorageFailure = AppFailure(AppErrorCode.storage);
const testDatabaseFailure = AppFailure(AppErrorCode.database);

class FakeAuthService implements AuthService {
  @override
  bool isConfigured = true;

  Object? errorToThrow;

  @override
  AuthUser? currentUser;

  Future<AuthUser?> Function()? getCurrentUserOverride;
  AuthUser signInUser = const AuthUser(
    id: 'user-a',
    email: 'owner@shop.com',
    shopName: 'Shop',
    emailVerified: true,
  );
  int signOutCalls = 0;
  Stream<AuthSessionEvent>? authStream;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() =>
      authStream ?? const Stream.empty();

  @override
  Future<AuthUser?> getCurrentUser() async {
    if (errorToThrow != null) throw errorToThrow!;
    if (getCurrentUserOverride != null) return getCurrentUserOverride!();
    return currentUser;
  }

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return signInUser;
  }

  @override
  Future<AuthUser> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return signInUser;
  }

  @override
  Future<void> signOut({String? expectedUserId}) async {
    if (expectedUserId != null && currentUser?.id != expectedUserId) {
      return;
    }
    signOutCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}

class FakeAuthBackend
    implements
        AuthSessionRepository,
        LoginRepository,
        SignUpRepository,
        ForgotPasswordRepository,
        VerifyEmailRepository,
        UpdatePasswordRepository {
  FakeAuthBackend({
    this.isConfigured = true,
    this.currentUser,
    this.linkedUserId,
    this.hasLocalData = true,
  });

  @override
  bool isConfigured;

  AuthUser? currentUser;
  String? linkedUserId;
  bool hasLocalData;

  final StreamController<AuthSessionEvent> events =
      StreamController<AuthSessionEvent>.broadcast();

  Either<AppFailure, AuthUser?>? currentUserOverride;
  Either<AppFailure, AuthUser>? signInOverride;
  Either<AppFailure, AuthUser>? signUpOverride;
  Either<AppFailure, void> signOutResult = const Right(null);
  Either<AppFailure, void> resetResult = const Right(null);
  Either<AppFailure, void> resendResult = const Right(null);
  Either<AppFailure, void> updatePasswordResult = const Right(null);
  Either<AppFailure, LedgerLinkStatus>? linkStatusOverride;
  Either<AppFailure, LedgerLinkStatus>? linkResultOverride;
  Either<AppFailure, bool>? hasLocalDataOverride;

  Future<Either<AppFailure, LedgerLinkStatus>> Function(String userId)?
  onGetLedgerLinkStatus;
  Future<Either<AppFailure, bool>> Function()? onHasLocalData;

  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int linkLedgerCalls = 0;
  int resetCalls = 0;
  int resendCalls = 0;
  int updatePasswordCalls = 0;
  Object? lastArgs;
  bool emitSignedOutEvent = false;
  final List<String?> signOutExpectedUserIds = [];

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => events.stream;

  @override
  Future<Either<AppFailure, AuthUser?>> getCurrentUser() async =>
      currentUserOverride ?? Right(currentUser);

  @override
  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastArgs = (email, password);
    final result = signInOverride ?? const Right(testUserA);
    result.match((_) {}, (user) {
      if (user.emailVerified) {
        currentUser = user;
        currentUserOverride = null;
      }
    });
    return result;
  }

  @override
  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) async {
    signUpCalls++;
    lastArgs = (email, password, shopName);
    final result = signUpOverride ?? const Right(testUnverifiedUser);
    result.match((_) {}, (user) {
      if (user.emailVerified) {
        currentUser = user;
        currentUserOverride = null;
      }
    });
    return result;
  }

  @override
  Future<Either<AppFailure, void>> signOut({String? expectedUserId}) async {
    signOutExpectedUserIds.add(expectedUserId);
    if (expectedUserId != null) {
      final activeUser = (currentUserOverride ?? Right(currentUser)).getOrElse(
        (_) => null,
      );
      if (activeUser == null || activeUser.id != expectedUserId) {
        return const Right(null);
      }
    }
    signOutCalls++;
    if (signOutResult.isRight()) {
      currentUser = null;
      currentUserOverride = null;
      if (emitSignedOutEvent && !events.isClosed) {
        events.add(const AuthSessionSignedOut());
        await Future<void>.microtask(() {});
      }
    }
    return signOutResult;
  }

  @override
  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastArgs = email;
    return resetResult;
  }

  @override
  Future<Either<AppFailure, void>> resendVerificationEmail(String email) async {
    resendCalls++;
    lastArgs = email;
    return resendResult;
  }

  @override
  Future<Either<AppFailure, void>> updatePassword(String newPassword) async {
    updatePasswordCalls++;
    lastArgs = newPassword;
    return updatePasswordResult;
  }

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> getLedgerLinkStatus(
    String userId,
  ) async {
    final override = onGetLedgerLinkStatus;
    if (override != null) return override(userId);
    if (linkStatusOverride != null) return linkStatusOverride!;
    if (linkedUserId == null) return const Right(LedgerLinkStatus.unlinked);
    if (linkedUserId == userId) {
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    return const Right(LedgerLinkStatus.linkedToOtherUser);
  }

  @override
  Future<Either<AppFailure, LedgerLinkStatus>> linkLedgerToUser(
    String userId,
  ) async {
    linkLedgerCalls++;
    if (linkResultOverride != null) return linkResultOverride!;
    if (linkedUserId == null) {
      linkedUserId = userId;
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    if (linkedUserId == userId) {
      return const Right(LedgerLinkStatus.linkedToCurrentUser);
    }
    return const Right(LedgerLinkStatus.linkedToOtherUser);
  }

  @override
  Future<Either<AppFailure, bool>> hasLocalLedgerData() async {
    if (onHasLocalData != null) return onHasLocalData!();
    if (hasLocalDataOverride != null) return hasLocalDataOverride!;
    return Right(hasLocalData);
  }

  Future<void> dispose() => events.close();
}

AuthSessionCubit buildSessionCubit(FakeAuthBackend backend) => AuthSessionCubit(
  backend,
  SignOutUseCase(backend),
  ConfirmLedgerLinkUseCase(backend),
);

Future<AuthSessionCubit> createInitializedSessionCubit(
  FakeAuthBackend backend,
) async {
  final cubit = buildSessionCubit(backend);
  await cubit.initialize();
  return cubit;
}

Future<void> pumpAuthScreen(
  WidgetTester tester,
  Widget screen, {
  List<BlocProvider> providers = const [],
  String locale = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppConstants.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: screen,
    ),
  );
  await tester.pumpWidget(
    providers.isEmpty
        ? app
        : MultiBlocProvider(providers: providers, child: app),
  );
  await tester.pumpAndSettle();
}

Finder authFormField(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

Finder authSnackBarText(String text) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(text));

Future<void> tapAuthButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(AppButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
