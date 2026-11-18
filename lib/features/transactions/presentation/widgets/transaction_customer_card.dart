import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../customers/domain/entities/customer_entity.dart';

class TransactionCustomerCard extends StatelessWidget {
  const TransactionCustomerCard({
    super.key,
    required this.customers,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });
  final List<CustomerEntity> customers;
  final CustomerEntity? selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(selected?.name ?? context.l10n.transactionChooseCustomer),
      trailing: TextButton(
        onPressed: !enabled
            ? null
            : () async {
                final chosen = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      itemBuilder: (_, index) {
                        final customer = customers[index];
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: customer.phone == null
                              ? null
                              : Text(customer.phone!),
                          onTap: () => Navigator.pop(sheetContext, customer.id),
                        );
                      },
                    ),
                  ),
                );
                if (chosen != null && context.mounted) onChanged(chosen);
              },
        child: Text(context.l10n.transactionChange),
      ),
    ),
  );
}
