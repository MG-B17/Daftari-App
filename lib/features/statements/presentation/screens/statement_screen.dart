import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../domain/entities/share_statement_result.dart';
import '../cubit/statement_cubit.dart';
import '../widgets/statement_body.dart';

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.statementTitle,
    body: BlocConsumer<StatementCubit, StatementState>(
      buildWhen: (previous, current) =>
          previous.loading != current.loading ||
          previous.range != current.range ||
          previous.statement != current.statement ||
          previous.failure != current.failure,
      listenWhen: (previous, current) =>
          previous.shareSubmissionId != current.shareSubmissionId &&
          (current.shareFailure != null || current.shareResult != null),
      listener: (context, state) async {
        if (state.shareFailure != null) {
          final message =
              state.shareFailureStage == StatementShareFailureStage.generation
              ? context.l10n.statementGenerateError
              : context.l10n.statementShareError;
          await AppErrorDialog.show(context, message: message);
          return;
        }
        switch (state.shareResult) {
          case ShareStatementResult.handedOff:
            await AppSuccessDialog.show(
              context,
              title: context.l10n.statementShareHandedOffTitle,
              message: context.l10n.statementShareHandedOffMessage,
            );
          case ShareStatementResult.systemShare:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(context.l10n.statementShareSheetOpened)),
              );
          case ShareStatementResult.dismissed:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(context.l10n.statementShareCancelled)),
              );
          case null:
            break;
        }
      },
      builder: (context, state) {
        if (state.loading) {
          return const DaftariLoading.screen();
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
