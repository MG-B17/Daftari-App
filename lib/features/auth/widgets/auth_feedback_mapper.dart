import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_error_dialog.dart';
import '../../../core/widgets/app_success_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../security/presentation/cubit/app_lock_cubit.dart';
import '../../security/presentation/cubit/app_lock_state.dart';
import '../session/domain/entities/auth_user.dart';
import '../session/presentation/cubit/auth_session_cubit.dart';
import '../session/presentation/cubit/auth_session_state.dart';
import 'ledger_link_confirmation_dialog.dart';

typedef AuthFeedbackDialogSpec = ({String title, String message, bool isError});

AuthFeedbackDialogSpec? authFeedbackDialogSpec(
  AppLocalizations l10n,
  AuthFeedback feedback,
) => switch (feedback) {
  AuthFeedback.none || AuthFeedback.passwordResetSent => null,
  AuthFeedback.signedIn => (
    title: l10n.authSignedInTitle,
    message: l10n.authSignedInSuccess,
    isError: false,
  ),
  AuthFeedback.ledgerLinked => (
    title: l10n.authAccountLinkedTitle,
    message: l10n.authLinkedSuccess,
    isError: false,
  ),
  AuthFeedback.signedOut => (
    title: l10n.authSignedOutTitle,
    message: l10n.authSignedOutSuccess,
    isError: false,
  ),
  AuthFeedback.passwordUpdated => (
    title: l10n.authPasswordUpdatedTitle,
    message: l10n.authPasswordUpdated,
    isError: false,
  ),
  AuthFeedback.verificationResent => (
    title: l10n.authResendSentTitle,
    message: l10n.authResendSent,
    isError: false,
  ),
  AuthFeedback.emailNotVerifiedYet => (
    title: l10n.authAccountEmailUnverified,
    message: l10n.authEmailNotVerifiedYet,
    isError: true,
  ),
  AuthFeedback.accountMismatchBlocked => (
    title: l10n.errorTitle,
    message: l10n.authErrorAccountMismatch,
    isError: true,
  ),
  AuthFeedback.authError => (
    title: l10n.errorTitle,
    message: l10n.authErrorAuth,
    isError: true,
  ),
  AuthFeedback.networkError => (
    title: l10n.errorTitle,
    message: l10n.authErrorNetwork,
    isError: true,
  ),
  AuthFeedback.unconfigured => (
    title: l10n.errorTitle,
    message: l10n.authErrorUnconfigured,
    isError: true,
  ),
  AuthFeedback.genericError => (
    title: l10n.errorTitle,
    message: l10n.authErrorGeneric,
    isError: true,
  ),
};

Future<void> showAuthFeedbackDialog(
  BuildContext context,
  AuthFeedback feedback,
) async {
  final spec = authFeedbackDialogSpec(context.l10n, feedback);
  if (spec == null) return;
  if (spec.isError) {
    await AppErrorDialog.show(
      context,
      title: spec.title,
      message: spec.message,
    );
  } else {
    await AppSuccessDialog.show(
      context,
      title: spec.title,
      message: spec.message,
    );
  }
}

/// Shared listener for auth screens that coordinates feedback dialogs,
/// first-time ledger link confirmation dialogs, email verification routing,
/// password recovery completion routing, and returning from auth routes once
/// authenticated.
class AuthFlowListener extends StatefulWidget {
  const AuthFlowListener({
    super.key,
    required this.child,
    this.navigateOnVerifyEmail = true,
    this.popOnAuthenticated = true,
    this.onPasswordUpdatedWithoutSession,
  });

  final Widget child;
  final bool navigateOnVerifyEmail;
  final bool popOnAuthenticated;
  final VoidCallback? onPasswordUpdatedWithoutSession;

  @override
  State<AuthFlowListener> createState() => _AuthFlowListenerState();
}

class _AuthFlowListenerState extends State<AuthFlowListener> {
  bool _presentingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingState());
  }

  bool _canPresent(BuildContext context) {
    final locked = context.read<AppLockCubit?>()?.state.locked ?? false;
    if (locked) return false;
    if (!TickerMode.of(context)) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _handlePendingState() {
    if (!mounted) return;
    final cubit = context.read<AuthSessionCubit?>();
    if (cubit == null) return;
    unawaited(
      _handleSessionState(context, cubit, cubit.state, allowNavigation: false),
    );
  }

  Future<void> _handleSessionState(
    BuildContext context,
    AuthSessionCubit cubit,
    AuthSessionState state, {
    required bool allowNavigation,
  }) async {
    if (!mounted || _presentingDialog || !_canPresent(context)) return;
    var showedFeedback = false;
    var handledPasswordUpdated = false;
    if (state.feedback != AuthFeedback.none &&
        authFeedbackDialogSpec(context.l10n, state.feedback) != null &&
        cubit.consumeFeedback(state.feedbackId)) {
      showedFeedback = true;
      handledPasswordUpdated = state.feedback == AuthFeedback.passwordUpdated;
      _presentingDialog = true;
      try {
        await showAuthFeedbackDialog(context, state.feedback);
      } finally {
        _presentingDialog = false;
      }
      if (!mounted) return;
    }

    final latest = cubit.state;
    if (!_canPresent(this.context)) return;

    if (latest.status == AuthStatus.linkConfirmationRequired &&
        latest.user != null) {
      await _handleLinkConfirmation(cubit, latest.user!);
      return;
    }

    final canNavigate = allowNavigation || showedFeedback;
    if (canNavigate &&
        widget.navigateOnVerifyEmail &&
        latest.status == AuthStatus.emailVerificationRequired) {
      _navigateToVerifyEmail(this.context, latest.pendingEmail);
      return;
    }
    if (canNavigate && widget.popOnAuthenticated && latest.isAuthenticated) {
      _exitAuthRoute(this.context);
      return;
    }
    if (handledPasswordUpdated &&
        widget.onPasswordUpdatedWithoutSession != null &&
        !latest.isAuthenticated &&
        latest.status != AuthStatus.linkConfirmationRequired) {
      widget.onPasswordUpdatedWithoutSession!();
      return;
    }

    if (latest.feedback != AuthFeedback.none &&
        authFeedbackDialogSpec(this.context.l10n, latest.feedback) != null &&
        cubit.hasUnconsumedFeedback(latest.feedbackId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handlePendingState(),
      );
    }
  }

  Future<void> _handleLinkConfirmation(
    AuthSessionCubit cubit,
    AuthUser promptedUser,
  ) async {
    if (!_canPresent(context)) return;
    if (!cubit.tryBeginLinkPrompt()) return;
    try {
      final confirmed = await LedgerLinkConfirmationDialog.show(context);
      if (!mounted) return;
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
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (current.status == AuthStatus.linkConfirmationRequired &&
              previous.user != current.user) ||
          (previous.feedbackId != current.feedbackId &&
              current.feedback != AuthFeedback.none),
      listener: (context, state) => unawaited(
        _handleSessionState(context, cubit, state, allowNavigation: true),
      ),
      child: widget.child,
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
