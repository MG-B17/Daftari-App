import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../customer_mock_data.dart';
import '../widgets/customer_details_body.dart';

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final customer = mockCustomerById(context.l10n, customerId);
    return AppScaffold(
      title: context.l10n.customerDetailsTitle,
      body: customer == null
          ? Center(child: Text(context.l10n.customerNotFound))
          : CustomerDetailsBody(customer: customer),
    );
  }
}
