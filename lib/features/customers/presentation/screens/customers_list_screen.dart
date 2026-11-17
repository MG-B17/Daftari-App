import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../widgets/customers_list_body.dart';

class CustomersListScreen extends StatelessWidget {
  const CustomersListScreen({super.key, this.showMockCustomers = true});

  final bool showMockCustomers;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.customersTitle,
    padding: EdgeInsets.zero,
    body: CustomersListBody(showMockCustomers: showMockCustomers),
    floatingActionButton: showMockCustomers
        ? FloatingActionButton.extended(
            onPressed: () => context.push(AppRoutes.customerNew),
            backgroundColor: context.colorScheme.primary,
            foregroundColor: context.colorScheme.onPrimary,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.customersAdd),
          )
        : null,
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  );
}
