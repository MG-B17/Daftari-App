import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../cubit/customer_details_cubit.dart';
import '../customer_error_message.dart';
import '../widgets/customer_details_body.dart';

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.l10n.customerDetailsTitle,
      body: BlocConsumer<CustomerDetailsCubit, CustomerDetailsState>(
        listenWhen: (previous, current) =>
            (previous.deleteSubmissionId != current.deleteSubmissionId &&
                (current.deleted || current.deleteFailure != null)) ||
            (previous.failure != current.failure &&
                current.failure != null &&
                current.customer != null),
        listener: (context, state) async {
          if (state.deleted) {
            await AppSuccessDialog.show(
              context,
              title: context.l10n.customerDeletedTitle,
              message: context.l10n.customerDeletedMessage,
            );
            if (!context.mounted) return;
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.customers);
            }
          } else if (state.deleteFailure != null) {
            await AppErrorDialog.show(
              context,
              message: customerErrorMessage(
                context,
                state.deleteFailure!.errorCode,
              ),
            );
          } else if (state.failure != null && state.customer != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  customerErrorMessage(context, state.failure!.errorCode),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const DaftariLoading.screen();
          }
          if (state.customer == null) {
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
                          context.read<CustomerDetailsCubit>().load(customerId),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              );
            }
            return Center(child: Text(context.l10n.customerNotFound));
          }
          return CustomerDetailsBody(
            customer: state.customer!,
            deleting: state.deleting,
          );
        },
      ),
    );
  }
}
