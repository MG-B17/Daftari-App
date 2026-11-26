import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../cubit/transaction_form_cubit.dart';
import '../widgets/transaction_form_body.dart';

class TransactionFormScreen extends StatelessWidget {
  const TransactionFormScreen({
    super.key,
    this.customerId,
    this.initialType,
    this.transactionId,
  });

  final String? customerId;
  final String? initialType;
  final String? transactionId;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: transactionId == null
        ? context.l10n.transactionNew
        : context.l10n.transactionEdit,
    body: BlocProvider(
      create: (_) => sl<TransactionFormCubit>()..load(transactionId),
      child: TransactionFormBody(
        customerId: customerId,
        initialType: initialType,
        transactionId: transactionId,
        isEdit: transactionId != null,
      ),
    ),
  );
}
