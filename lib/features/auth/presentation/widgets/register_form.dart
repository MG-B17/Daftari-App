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

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _shopName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.authRegisterMockNotice)),
      );
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
            icon: Icons.storefront_outlined,
            badge: l10n.authSecureBadge,
            title: l10n.authRegisterHeading,
            subtitle: l10n.authRegisterSubtitle,
          ),
          SizedBox(height: AppSpacing.lg),
          AuthCard(
            child: Column(
              children: [
                AppTextField(
                  key: const ValueKey('auth-register-shop'),
                  label: l10n.authShopName,
                  hintText: l10n.authShopNameHint,
                  optionalLabel: l10n.authShopNameViewerHint,
                  isRequired: true,
                  controller: _shopName,
                  textInputAction: TextInputAction.next,
                  prefix: const Icon(Icons.storefront_outlined),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.authShopNameRequired
                      : null,
                ),
                SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const ValueKey('auth-register-email'),
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
                  key: const ValueKey('auth-register-password'),
                  label: l10n.authPassword,
                  hintText: l10n.authPasswordHint,
                  isRequired: true,
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.password(value, locale: locale),
                ),
                SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  key: const ValueKey('auth-register-confirm'),
                  label: l10n.authConfirmPassword,
                  hintText: l10n.authPasswordHint,
                  isRequired: true,
                  controller: _confirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) => value != _password.text
                      ? l10n.authPasswordMismatch
                      : null,
                ),
                SizedBox(height: AppSpacing.md),
                AuthNote(
                  message: l10n.authRegisterConsent,
                  icon: Icons.privacy_tip_outlined,
                ),
                SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.authRegisterAction,
                  trailingIcon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  onPressed: _submit,
                ),
                SizedBox(height: AppSpacing.compact),
                AuthMockNotice(text: l10n.authRegisterMockNotice),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AuthSwitchPrompt(
            prompt: l10n.authHaveAccount,
            action: l10n.authSignInLink,
            onTap: () => context.pushReplacement(AppRoutes.authLogin),
          ),
          SizedBox(height: AppSpacing.lg),
          AuthOfflineFooter(onContinue: _continueOffline),
        ],
      ),
    );
  }
}
