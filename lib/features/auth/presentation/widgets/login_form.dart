import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'auth_card.dart';
import 'auth_header.dart';
import 'auth_mock_notice.dart';
import 'auth_note.dart';
import 'auth_offline_footer.dart';
import 'auth_password_field.dart';
import 'auth_switch_prompt.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.authLoginMockNotice)));
  }

  void _continueOffline() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthHeader(
            icon: Icons.shield_outlined,
            badge: l10n.authSecureBadge,
            title: l10n.authLoginHeading,
            subtitle: l10n.authLoginSubtitle,
          ),
          SizedBox(height: AppSpacing.lg),
          AuthCard(
            child: Column(
              children: [
                AppTextField(
                  key: const ValueKey('auth-login-email'),
                  label: l10n.authEmail,
                  hintText: l10n.authEmailHint,
                  isRequired: true,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefix: const Icon(Icons.mail_outline_rounded),
                  validator: (value) => Validators.email(value, locale: locale),
                ),
                SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  key: const ValueKey('auth-login-password'),
                  label: l10n.authPassword,
                  hintText: l10n.authPasswordHint,
                  isRequired: true,
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  onForgotPassword: () =>
                      context.push(AppRoutes.authForgotPassword),
                  validator: (value) =>
                      Validators.password(value, locale: locale),
                ),
                SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.authSignIn,
                  trailingIcon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  onPressed: _submit,
                ),
                SizedBox(height: AppSpacing.compact),
                AuthMockNotice(text: l10n.authLoginMockNotice),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AuthSwitchPrompt(
            prompt: l10n.authNoAccount,
            action: l10n.authCreateAccount,
            onTap: () => context.pushReplacement(AppRoutes.authRegister),
          ),
          SizedBox(height: AppSpacing.lg),
          AuthNote(
            title: l10n.authOfflineNoteTitle,
            message: l10n.authOfflineNote,
          ),
          SizedBox(height: AppSpacing.sm),
          AuthOfflineFooter(onContinue: _continueOffline),
        ],
      ),
    );
  }
}
