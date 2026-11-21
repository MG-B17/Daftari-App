import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/auth_page_body.dart';
import '../widgets/verify_email_body.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.authVerifyTitle,
    body: AuthPageBody(children: [VerifyEmailBody(email: email)]),
  );
}
