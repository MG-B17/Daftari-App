import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../cubit/customers_list_cubit.dart';
import '../widgets/customers_list_body.dart';

class CustomersListScreen extends StatelessWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CustomersListCubit, CustomersListState>(
        builder: (context, state) => AppScaffold(
          title: context.l10n.customersTitle,
          padding: EdgeInsets.zero,
          body: const CustomersListBody(),
          floatingActionButton:
              state.loading || state.failure != null || state.customers.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.push(AppRoutes.customerNew),
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: context.colorScheme.onPrimary,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.customersAdd),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ),
      );
}
