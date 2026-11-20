import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/statement_body.dart';

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.statementTitle,
    body: const StatementBody(),
  );
}
