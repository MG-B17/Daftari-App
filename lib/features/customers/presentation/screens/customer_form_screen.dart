import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../domain/entities/picked_contact.dart';
import '../cubit/customer_form_cubit.dart';
import '../customer_error_message.dart';
import '../widgets/customer_form_body.dart';

class CustomerFormScreen extends StatelessWidget {
  const CustomerFormScreen({super.key, this.customerId, this.initialContact});

  final String? customerId;
  final PickedContact? initialContact;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: customerId == null
          ? context.l10n.customerNewTitle
          : context.l10n.customerEditTitle,
      body: BlocConsumer<CustomerFormCubit, CustomerFormState>(
        listenWhen: (previous, current) =>
            previous.submissionId != current.submissionId &&
            (current.saved || current.submissionFailure != null),
        listener: (context, state) async {
          if (state.saved) {
            final l10n = context.l10n;
            await AppSuccessDialog.show(
              context,
              title: customerId == null
                  ? l10n.customerCreatedTitle
                  : l10n.customerUpdatedTitle,
              message: customerId == null
                  ? l10n.customerCreatedMessage
                  : l10n.customerUpdatedMessage,
            );
            if (!context.mounted) return;
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.customers);
            }
          } else if (state.submissionFailure != null) {
            await AppErrorDialog.show(
              context,
              message: customerErrorMessage(
                context,
                state.submissionFailure!.errorCode,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const DaftariLoading.screen();
          }
          if (customerId != null && state.customer == null) {
            if (state.failure != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customerErrorMessage(context, state.failure!.errorCode),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<CustomerFormCubit>().load(customerId!),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              );
            }
            return Center(child: Text(context.l10n.customerNotFound));
          }
          return CustomerFormBody(
            customer: state.customer,
            initialContact: initialContact,
            saving: state.saving,
          );
        },
      ),
    );
  }
}
