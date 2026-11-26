import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/app_routes.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../session/presentation/cubit/auth_session_cubit.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../../widgets/auth_card.dart';
import '../../../widgets/auth_feedback_mapper.dart';
import '../../../widgets/auth_header.dart';
import '../../../widgets/auth_note.dart';
import '../../../widgets/auth_offline_footer.dart';
import '../../../widgets/auth_password_field.dart';
import '../../../widgets/auth_switch_prompt.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

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

  Future<void> _submit() async {
    final loginCubit = context.read<LoginCubit?>();
    final sessionBusy = context.read<AuthSessionCubit?>()?.state.busy ?? false;
    if ((loginCubit?.state.busy ?? false) || sessionBusy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await loginCubit?.signIn(email: _email.text, password: _password.text);
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
    final cubit = context.read<LoginCubit?>();
    final loginBusy = context.select<LoginCubit?, bool>(
      (cubit) => cubit?.state.busy ?? false,
    );
    final sessionBusy = context.select<AuthSessionCubit?, bool>(
      (sessionCubit) => sessionCubit?.state.busy ?? false,
    );
    final busy = loginBusy || sessionBusy;
    Widget form = Form(
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
                  enabled: !busy,
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
                  enabled: !busy,
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
                  isLoading: busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AuthSwitchPrompt(
            prompt: l10n.authNoAccount,
            action: l10n.authCreateAccount,
            onTap: busy
                ? null
                : () => context.pushReplacement(AppRoutes.authRegister),
          ),
          SizedBox(height: AppSpacing.lg),
          AuthNote(
            title: l10n.authOfflineNoteTitle,
            message: l10n.authOfflineNote,
          ),
          SizedBox(height: AppSpacing.sm),
          AuthOfflineFooter(onContinue: busy ? null : _continueOffline),
        ],
      ),
    );
    if (cubit != null) {
      form = BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) =>
            previous.feedbackId != current.feedbackId &&
            current.feedback != AuthFeedback.none,
        listener: (context, state) =>
            unawaited(showAuthFeedbackDialog(context, state.feedback)),
        child: form,
      );
    }
    return AuthFlowListener(child: form);
  }
}
