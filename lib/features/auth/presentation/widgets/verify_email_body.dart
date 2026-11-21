import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import 'auth_card.dart';
import 'auth_header.dart';
import 'auth_mock_notice.dart';

class VerifyEmailBody extends StatelessWidget {
  const VerifyEmailBody({super.key, this.email});

  final String? email;

  void _resend(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.authResendSent)));
  }

  void _verified(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.authVerifyMockNotice)),
      );
  }

  void _backToLogin(BuildContext context) {
    context.pushReplacement(AppRoutes.authLogin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = this.email?.trim();
    return Column(
      children: [
        AuthHeader(
          icon: Icons.mark_email_read_outlined,
          title: l10n.authVerifyHeading,
          subtitle: email == null || email.isEmpty
              ? l10n.authVerifyGenericSubtitle
              : l10n.authVerifySubtitle(email),
        ),
        SizedBox(height: AppSpacing.lg),
        AuthCard(
          child: Column(
            children: [
              if (email != null && email.isNotEmpty) ...[
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
                        email,
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
                onPressed: () => _resend(context),
              ),
              SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.authVerifiedAction,
                variant: AppButtonVariant.outlined,
                fullWidth: true,
                onPressed: () => _verified(context),
              ),
              SizedBox(height: AppSpacing.compact),
              AuthMockNotice(text: l10n.authVerifyMockNotice),
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
  }
}
