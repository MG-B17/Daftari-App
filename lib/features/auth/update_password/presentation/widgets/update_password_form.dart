import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/app_routes.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../session/presentation/cubit/auth_session_cubit.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../../widgets/auth_card.dart';
import '../../../widgets/auth_feedback_mapper.dart';
import '../../../widgets/auth_header.dart';
import '../../../widgets/auth_password_field.dart';
import '../cubit/update_password_cubit.dart';
import '../cubit/update_password_state.dart';

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
    final cubit = context.read<UpdatePasswordCubit?>();
    if (cubit == null) return;
    final updated = await cubit.updatePassword(_password.text);
    if (!updated || !mounted) return;
    if (cubit.shouldNavigateToLoginAfterUpdate) {
      GoRouter.maybeOf(context)?.go(AppRoutes.authLogin);
    }
  }

  Future<void> _backToLogin() async {
    final updateCubit = context.read<UpdatePasswordCubit?>();
    if (updateCubit != null) {
      final cancelled = await updateCubit.cancelRecovery();
      if (!cancelled || !mounted) return;
    } else {
      final sessionCubit = context.read<AuthSessionCubit?>();
      if (sessionCubit != null) {
        final cancelled = await sessionCubit.cancelPasswordRecovery();
        if (!cancelled || !mounted) return;
      }
    }
    GoRouter.maybeOf(context)?.go(AppRoutes.authLogin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final cubit = context.read<UpdatePasswordCubit?>();
    final updateBusy = context.select<UpdatePasswordCubit?, bool>(
      (updateCubit) => updateCubit?.state.busy ?? false,
    );
    final sessionBusy = context.select<AuthSessionCubit?, bool>(
      (sessionCubit) => sessionCubit?.state.busy ?? false,
    );
    final busy = updateBusy || sessionBusy;
    Widget form = Form(
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
            onPressed: busy ? null : _backToLogin,
            child: Text(l10n.authBackToLogin),
          ),
        ],
      ),
    );
    if (cubit != null) {
      form = BlocListener<UpdatePasswordCubit, UpdatePasswordState>(
        listenWhen: (previous, current) =>
            previous.feedbackId != current.feedbackId &&
            current.feedback != AuthFeedback.none,
        listener: (context, state) =>
            showAuthFeedbackSnackBar(context, state.feedback),
        child: form,
      );
    }
    return AuthFlowListener(navigateOnVerifyEmail: false, child: form);
  }
}
