import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import 'auth_card.dart';
import 'auth_header.dart';
import 'auth_mock_notice.dart';
import 'auth_password_field.dart';

class UpdatePasswordForm extends StatefulWidget {
  const UpdatePasswordForm({super.key});

  @override
  State<UpdatePasswordForm> createState() => _UpdatePasswordFormState();
}

class _UpdatePasswordFormState extends State<UpdatePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
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
        SnackBar(content: Text(context.l10n.authUpdateMockNotice)),
      );
  }

  void _backToLogin() {
    context.pushReplacement(AppRoutes.authLogin);
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
            icon: Icons.password_rounded,
            title: l10n.authUpdateHeading,
            subtitle: l10n.authUpdateSubtitle,
          ),
          SizedBox(height: AppSpacing.lg),
          AuthCard(
            child: Column(
              children: [
                AuthPasswordField(
                  key: const ValueKey('auth-update-password'),
                  label: l10n.authNewPassword,
                  hintText: l10n.authPasswordHint,
                  isRequired: true,
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.password(value, locale: locale),
                ),
                SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  key: const ValueKey('auth-update-confirm'),
                  label: l10n.authConfirmPassword,
                  hintText: l10n.authPasswordHint,
                  isRequired: true,
                  controller: _confirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) => value != _password.text
                      ? l10n.authPasswordMismatch
                      : null,
                ),
                SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.authUpdatePasswordAction,
                  fullWidth: true,
                  onPressed: _submit,
                ),
                SizedBox(height: AppSpacing.compact),
                AuthMockNotice(text: l10n.authUpdateMockNotice),
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
    );
  }
}
