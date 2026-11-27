import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/services/session_commit_gate/session_commit_gate.dart';
import '../../domain/entities/auth_session_event.dart';
import '../../domain/entities/auth_user.dart';
import 'supabase_bootstrap.dart';

abstract interface class AuthService {
  bool get isConfigured;

  /// Synchronous snapshot of the currently authenticated user, if any.
  AuthUser? get currentUser;

  Stream<AuthSessionEvent> watchAuthChanges();

  Future<AuthUser?> getCurrentUser();

  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  });

  Future<void> signOut({String? expectedUserId});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> resendVerificationEmail(String email);

  Future<void> updatePassword(String newPassword);
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._bootstrap, {this._commitGate});

  final SupabaseBootstrap _bootstrap;
  final SessionCommitGate? _commitGate;

  sb.SupabaseClient? get _client => _bootstrap.client;

  @override
  bool get isConfigured => _bootstrap.isConfigured;

  sb.SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) throw const AuthException();
    return client;
  }

  @override
  Stream<AuthSessionEvent> watchAuthChanges() {
    final client = _client;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange.asyncExpand((authState) async* {
      final session = authState.session;
      final user = session?.user;
      switch (authState.event) {
        case sb.AuthChangeEvent.passwordRecovery:
          if (user != null) {
            yield AuthSessionPasswordRecovery(_mapUser(user, hasSession: true));
          }
        case sb.AuthChangeEvent.signedOut:
          yield const AuthSessionSignedOut();
        case sb.AuthChangeEvent.signedIn:
        case sb.AuthChangeEvent.tokenRefreshed:
        case sb.AuthChangeEvent.userUpdated:
        case sb.AuthChangeEvent.initialSession:
          if (user != null) {
            yield AuthSessionSignedIn(_mapUser(user, hasSession: true));
          } else if (authState.event == sb.AuthChangeEvent.initialSession) {
            yield const AuthSessionSignedOut();
          }
        case sb.AuthChangeEvent.mfaChallengeVerified:
          break;
        case sb.AuthChangeEvent.userDeleted:
          yield const AuthSessionSignedOut();
      }
    });
  }

  @override
  AuthUser? get currentUser {
    final client = _client;
    if (client == null) return null;
    final session = client.auth.currentSession;
    if (session == null) return null;
    return _mapUser(session.user, hasSession: true);
  }

  @override
  Future<AuthUser?> getCurrentUser() async => currentUser;

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final sb.AuthResponse response;
    try {
      response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on sb.AuthException catch (error) {
      if (isEmailNotConfirmedError(error)) {
        return AuthUser(id: '', email: email, emailVerified: false);
      }
      rethrow;
    }
    final user = response.user;
    if (user == null) throw const AuthException();

    final mapped = _mapUser(user, hasSession: response.session != null);
    if (!mapped.emailVerified && response.session != null) {
      await client.auth.signOut(scope: sb.SignOutScope.local);
    }
    return mapped;
  }

  static bool isEmailNotConfirmedError(sb.AuthException error) =>
      error.code?.toLowerCase() == 'email_not_confirmed';

  @override
  Future<AuthUser> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) async {
    final client = _requireClient();
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'shop_name': shopName},
      emailRedirectTo: SupabaseBootstrap.authCallbackUrl,
    );
    final user = response.user;
    if (user == null) throw const AuthException();
    return _mapUser(user, hasSession: response.session != null);
  }

  @override
  Future<void> signOut({String? expectedUserId}) {
    Future<void> performSignOut() async {
      final client = _client;
      if (client == null) return;
      if (expectedUserId != null && currentUser?.id != expectedUserId) {
        return;
      }
      await client.auth.signOut(scope: sb.SignOutScope.local);
    }

    final gate = _commitGate;
    return gate == null
        ? performSignOut()
        : gate.runSessionInvalidation(performSignOut);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final client = _requireClient();
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseBootstrap.authCallbackUrl,
    );
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    final client = _requireClient();
    await client.auth.resend(
      type: sb.OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseBootstrap.authCallbackUrl,
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final client = _requireClient();
    await client.auth.updateUser(sb.UserAttributes(password: newPassword));
  }

  static AuthUser _mapUser(sb.User user, {required bool hasSession}) {
    final rawShopName = user.userMetadata?['shop_name'];
    final shopName = rawShopName is String && rawShopName.trim().isNotEmpty
        ? rawShopName.trim()
        : null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      shopName: shopName,
      emailVerified: hasSession && user.emailConfirmedAt != null,
    );
  }
}
