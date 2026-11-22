import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/app_routes.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../session/presentation/cubit/auth_session_cubit.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../../widgets/auth_card.dart';
import '../../../widgets/auth_feedback_mapper.dart';
import '../../../widgets/auth_header.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';

class VerifyEmailBody extends StatelessWidget {
  const VerifyEmailBody({super.key, this.email});

  final String? email;

  void _backToLogin(BuildContext context) {
    context.pushReplacement(AppRoutes.authLogin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<VerifyEmailCubit?>();
    final pendingEmail = context.select<AuthSessionCubit?, String?>(
      (sessionCubit) => sessionCubit?.state.pendingEmail,
    );
    final busy = context.select<VerifyEmailCubit?, bool>(
      (verifyCubit) => verifyCubit?.state.busy ?? false,
    );
    final resolvedEmail = (email ?? pendingEmail)?.trim();
    final hasEmail = resolvedEmail != null && resolvedEmail.isNotEmpty;
    Widget content = Column(
      children: [
        AuthHeader(
          icon: Icons.mark_email_read_outlined,
          title: l10n.authVerifyHeading,
          subtitle: hasEmail
              ? l10n.authVerifySubtitle(resolvedEmail)
              : l10n.authVerifyGenericSubtitle,
        ),
        SizedBox(height: AppSpacing.lg),
        AuthCard(
          child: Column(
            children: [
              if (hasEmail) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.alternate_email_rounded,
                      size: AppSpacing.iconMedium,
                      color: context.colorScheme.primary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        resolvedEmail,
                        textAlign: TextAlign.center,
                        style: context.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: l10n.authResendVerification,
                fullWidth: true,
                isLoading: busy,
                onPressed: hasEmail
                    ? () => context
                          .read<VerifyEmailCubit?>()
                          ?.resendVerificationEmail(resolvedEmail)
                    : null,
              ),
              SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.authVerifiedAction,
                variant: AppButtonVariant.outlined,
                fullWidth: true,
                onPressed: busy
                    ? null
                    : () => context
                          .read<VerifyEmailCubit?>()
                          ?.checkEmailVerified(email: resolvedEmail),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => _backToLogin(context),
          child: Text(l10n.authBackToLogin),
        ),
      ],
    );
    if (cubit != null) {
      content = BlocListener<VerifyEmailCubit, VerifyEmailState>(
        listenWhen: (previous, current) =>
            previous.feedbackId != current.feedbackId &&
            current.feedback != AuthFeedback.none,
        listener: (context, state) =>
            showAuthFeedbackSnackBar(context, state.feedback),
        child: content,
      );
    }
    return AuthFlowListener(navigateOnVerifyEmail: false, child: content);
  }
}
