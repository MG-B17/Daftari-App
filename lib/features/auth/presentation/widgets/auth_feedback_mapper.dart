import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
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
  bool _showingDialog = false;

  Future<void> _handleLinkConfirmation(BuildContext context) async {
    if (_showingDialog) return;
    _showingDialog = true;
    try {
      final confirmed = await LedgerLinkConfirmationDialog.show(context);
      if (!context.mounted) return;
      await context.read<AuthCubit>().confirmLedgerLink(confirmed: confirmed);
    } finally {
      _showingDialog = false;
    }
  }

  void _navigateToVerifyEmail(BuildContext context, String? email) {
    final query = email != null && email.trim().isNotEmpty
        ? '?email=${Uri.encodeQueryComponent(email.trim())}'
        : '';
    final router = GoRouter.maybeOf(context);
    router?.pushReplacement('${AppRoutes.authVerifyEmail}$query');
  }

  void _exitAuthRoute(BuildContext context) {
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
    final cubit = context.read<AuthCubit?>();
    if (cubit == null) return widget.child;
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.linkConfirmationRequired) {
          _handleLinkConfirmation(context);
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
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous.feedbackId != current.feedbackId &&
            current.feedback != AuthFeedback.none,
        listener: (context, state) =>
            showAuthFeedbackSnackBar(context, state.feedback),
        child: widget.child,
      ),
    );
  }
}
