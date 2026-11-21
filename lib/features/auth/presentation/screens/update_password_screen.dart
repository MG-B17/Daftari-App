import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/auth_page_body.dart';
import '../widgets/update_password_form.dart';

class UpdatePasswordScreen extends StatelessWidget {
  const UpdatePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.authUpdateTitle,
    body: const AuthPageBody(children: [UpdatePasswordForm()]),
  );
}
