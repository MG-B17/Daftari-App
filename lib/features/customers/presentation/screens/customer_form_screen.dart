import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
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
            previous.failure != current.failure ||
            previous.saved != current.saved,
        listener: (context, state) {
          if (state.saved) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers');
            }
          } else if (state.failure != null &&
              (customerId == null || state.customer != null)) {
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
            return const Center(child: CircularProgressIndicator());
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
