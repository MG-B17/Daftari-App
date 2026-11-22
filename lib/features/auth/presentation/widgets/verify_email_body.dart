import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/auth_cubit.dart';
import 'auth_card.dart';
import 'auth_feedback_mapper.dart';
import 'auth_header.dart';

class VerifyEmailBody extends StatelessWidget {
  const VerifyEmailBody({super.key, this.email});

  final String? email;

  void _backToLogin(BuildContext context) {
    context.pushReplacement(AppRoutes.authLogin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pendingEmail = context.select<AuthCubit?, String?>(
      (cubit) => cubit?.state.pendingEmail,
    );
    final busy = context.select<AuthCubit?, bool>(
      (cubit) => cubit?.state.busy ?? false,
    );
    final resolvedEmail = (email ?? pendingEmail)?.trim();
    final hasEmail = resolvedEmail != null && resolvedEmail.isNotEmpty;
    return AuthFlowListener(
      navigateOnVerifyEmail: false,
      child: Column(
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
                            .read<AuthCubit?>()
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
                      : () => context.read<AuthCubit?>()?.checkEmailVerified(),
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
      ),
    );
  }
}
