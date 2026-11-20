import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/statement_body.dart';
import '../cubit/statement_cubit.dart';

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.statementTitle,
    body: BlocConsumer<StatementCubit, StatementState>(
      listenWhen: (previous, current) =>
          current.shareFailure != null &&
          previous.shareFailure != current.shareFailure,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.statementShareError))),
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.failure != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.statementLoadError),
                TextButton(
                  onPressed: () =>
                      context.read<StatementCubit>().load(customerId),
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          );
        }
        if (state.notFound) {
          return Center(child: Text(context.l10n.customerNotFound));
        }
        return StatementBody(state: state);
      },
    ),
  );
}
