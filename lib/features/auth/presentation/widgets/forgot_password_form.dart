import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';
import 'auth_card.dart';
import 'auth_feedback_mapper.dart';
import 'auth_header.dart';

class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({super.key});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AuthCubit?>();
    if (cubit == null) return;
    final sent = await cubit.sendPasswordReset(_email.text);
    if (sent && mounted) {
      setState(() => _sent = true);
    }
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.authLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final busy = context.select<AuthCubit?, bool>(
      (cubit) => cubit?.state.busy ?? false,
    );
    return AuthFlowListener(
      navigateOnVerifyEmail: false,
      popOnAuthenticated: false,
      child: _sent
          ? Column(
              children: [
                AuthHeader(
                  icon: Icons.mark_email_read_outlined,
                  title: l10n.authResetSentTitle,
                  subtitle: l10n.authResetSentMessage(_email.text.trim()),
                ),
                SizedBox(height: AppSpacing.lg),
                AuthCard(
                  child: Column(
                    children: [
                      AppButton(
                        label: l10n.authBackToLogin,
                        fullWidth: true,
                        onPressed: _backToLogin,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  AuthHeader(
                    icon: Icons.lock_reset_rounded,
                    title: l10n.authForgotHeading,
                    subtitle: l10n.authForgotSubtitle,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  AuthCard(
                    child: Column(
                      children: [
                        AppTextField(
                          key: const ValueKey('auth-forgot-email'),
                          label: l10n.authEmail,
                          hintText: l10n.authEmailHint,
                          isRequired: true,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          prefix: const Icon(Icons.mail_outline_rounded),
                          validator: (value) =>
                              Validators.email(value, locale: locale),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: l10n.authSendResetLink,
                          trailingIcon: Icons.arrow_forward_rounded,
                          fullWidth: true,
                          isLoading: busy,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _backToLogin,
                    child: Text(l10n.authBackToLogin),
                  ),
                ],
              ),
            ),
    );
  }
}
