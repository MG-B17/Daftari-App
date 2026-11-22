import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../security/presentation/cubit/app_lock_cubit.dart';
import '../../security/presentation/cubit/app_lock_state.dart';
import '../session/domain/entities/auth_user.dart';
import '../session/presentation/cubit/auth_session_cubit.dart';
import '../session/presentation/cubit/auth_session_state.dart';
import 'ledger_link_confirmation_dialog.dart';

String? authFeedbackMessage(AppLocalizations l10n, AuthFeedback feedback) =>
    switch (feedback) {
      AuthFeedback.none => null,
      AuthFeedback.accountMismatchBlocked => l10n.authErrorAccountMismatch,
      AuthFeedback.authError => l10n.authErrorAuth,
      AuthFeedback.networkError => l10n.authErrorNetwork,
      AuthFeedback.unconfigured => l10n.authErrorUnconfigured,
      AuthFeedback.genericError => l10n.authErrorGeneric,
      AuthFeedback.verificationResent => l10n.authResendSent,
      AuthFeedback.emailNotVerifiedYet => l10n.authEmailNotVerifiedYet,
      AuthFeedback.passwordResetSent => null,
      AuthFeedback.passwordUpdated => l10n.authPasswordUpdated,
      AuthFeedback.signedOut => l10n.authSignedOutSuccess,
      AuthFeedback.ledgerLinked => l10n.authLinkedSuccess,
    };

void showAuthFeedbackSnackBar(BuildContext context, AuthFeedback feedback) {
  final message = authFeedbackMessage(context.l10n, feedback);
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shared listener for auth screens that handles feedback snackbars,
/// first-time ledger link confirmation dialogs, email verification routing,
/// and returning from auth routes once authenticated.
class AuthFlowListener extends StatefulWidget {
  const AuthFlowListener({
    super.key,
    required this.child,
    this.navigateOnVerifyEmail = true,
    this.popOnAuthenticated = true,
  });

  final Widget child;
  final bool navigateOnVerifyEmail;
  final bool popOnAuthenticated;

  @override
  State<AuthFlowListener> createState() => _AuthFlowListenerState();
}

class _AuthFlowListenerState extends State<AuthFlowListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingState());
  }

  bool _canPresent(BuildContext context) {
    final locked = context.read<AppLockCubit?>()?.state.locked ?? false;
    if (locked) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _maybeShowFeedback(
    BuildContext context,
    AuthSessionCubit cubit,
    AuthSessionState state,
  ) {
    if (!_canPresent(context)) return;
    if (state.feedback == AuthFeedback.none) return;
    final message = authFeedbackMessage(context.l10n, state.feedback);
    if (message == null) return;
    if (!cubit.consumeFeedback(state.feedbackId)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handlePendingState() {
    if (!mounted) return;
    final cubit = context.read<AuthSessionCubit?>();
    if (cubit == null) return;
    final state = cubit.state;
    if (!_canPresent(context)) return;
    _maybeShowFeedback(context, cubit, state);
    if (state.status == AuthStatus.linkConfirmationRequired &&
        state.user != null) {
      unawaited(_handleLinkConfirmation(context, cubit, state.user!));
    }
  }

  Future<void> _handleLinkConfirmation(
    BuildContext context,
    AuthSessionCubit cubit,
    AuthUser promptedUser,
  ) async {
    if (!_canPresent(context)) return;
    if (!cubit.tryBeginLinkPrompt()) return;
    try {
      final confirmed = await LedgerLinkConfirmationDialog.show(context);
      if (!context.mounted) return;
      await cubit.confirmLedgerLink(
        confirmed: confirmed,
        expectedUserId: promptedUser.id,
      );
    } finally {
      cubit.endLinkPrompt();
    }
    if (!mounted) return;
    final nextState = cubit.state;
    if (nextState.status == AuthStatus.linkConfirmationRequired &&
        nextState.user != null &&
        nextState.user!.id != promptedUser.id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handlePendingState(),
      );
    }
  }

  void _navigateToVerifyEmail(BuildContext context, String? email) {
    if (!_canPresent(context)) return;
    final query = email != null && email.trim().isNotEmpty
        ? '?email=${Uri.encodeQueryComponent(email.trim())}'
        : '';
    final router = GoRouter.maybeOf(context);
    router?.pushReplacement('${AppRoutes.authVerifyEmail}$query');
  }

  void _exitAuthRoute(BuildContext context) {
    if (!_canPresent(context)) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthSessionCubit?>();
    if (cubit == null) return widget.child;
    final lockCubit = context.read<AppLockCubit?>();
    Widget listener = BlocListener<AuthSessionCubit, AuthSessionState>(
      listener: (context, state) {
        if (!_canPresent(context)) return;
        if (state.status == AuthStatus.linkConfirmationRequired &&
            state.user != null) {
          unawaited(_handleLinkConfirmation(context, cubit, state.user!));
          return;
        }
        if (widget.navigateOnVerifyEmail &&
            state.status == AuthStatus.emailVerificationRequired) {
          _navigateToVerifyEmail(context, state.pendingEmail);
          return;
        }
        if (widget.popOnAuthenticated && state.isAuthenticated) {
          _exitAuthRoute(context);
        }
      },
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (current.status == AuthStatus.linkConfirmationRequired &&
              previous.user != current.user),
      child: BlocListener<AuthSessionCubit, AuthSessionState>(
        listenWhen: (previous, current) =>
            previous.feedbackId != current.feedbackId &&
            current.feedback != AuthFeedback.none,
        listener: (context, state) => _maybeShowFeedback(context, cubit, state),
        child: widget.child,
      ),
    );
    if (lockCubit != null) {
      listener = BlocListener<AppLockCubit, AppLockState>(
        listenWhen: (previous, current) => previous.locked && !current.locked,
        listener: (_, _) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handlePendingState(),
        ),
        child: listener,
      );
    }
    return listener;
  }
}
