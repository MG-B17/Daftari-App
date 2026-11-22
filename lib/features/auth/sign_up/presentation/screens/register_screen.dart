import 'package:flutter/material.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../widgets/auth_page_body.dart';
import '../widgets/register_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.authRegisterTitle,
    body: const AuthPageBody(children: [RegisterForm()]),
  );
}
