import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/auth_page_body.dart';
import '../widgets/forgot_password_form.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.authForgotTitle,
    body: const AuthPageBody(children: [ForgotPasswordForm()]),
  );
}
