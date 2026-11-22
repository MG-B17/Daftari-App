import 'package:flutter/material.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../widgets/auth_page_body.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.authLoginTitle,
    body: const AuthPageBody(children: [LoginForm()]),
  );
}
