import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'auth_card.dart';
import 'auth_feedback_mapper.dart';
import 'auth_header.dart';
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AuthCubit?>();
    if (cubit == null) return;
    final updated = await cubit.updatePassword(_password.text);
    if (!updated || !mounted) return;
    if (!cubit.state.isAuthenticated &&
        cubit.state.status != AuthStatus.linkConfirmationRequired) {
      GoRouter.maybeOf(context)?.go(AppRoutes.authLogin);
    }
  }

  void _backToLogin() {
    context.read<AuthCubit?>()?.cancelPasswordRecovery();
    GoRouter.maybeOf(context)?.go(AppRoutes.authLogin);
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
      child: Form(
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
