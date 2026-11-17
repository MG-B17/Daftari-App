import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../customer_mock_data.dart';
import '../widgets/customer_form_body.dart';

class CustomerFormScreen extends StatelessWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final String? customerId;

  @override
  Widget build(BuildContext context) {
    final customer = customerId == null
        ? null
        : mockCustomerById(context.l10n, customerId!);
    return AppScaffold(
      title: customerId == null
          ? context.l10n.customerNewTitle
          : context.l10n.customerEditTitle,
      body: customerId != null && customer == null
          ? Center(child: Text(context.l10n.customerNotFound))
          : CustomerFormBody(customer: customer),
    );
  }
}
