import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../customer_mock_data.dart';

class CustomerFormBody extends StatefulWidget {
  const CustomerFormBody({super.key, this.customer});

  final CustomerMock? customer;

  @override
  State<CustomerFormBody> createState() => _CustomerFormBodyState();
}

class _CustomerFormBodyState extends State<CustomerFormBody> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name);
    _phone = TextEditingController(text: widget.customer?.phone);
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.customersMaxWidth),
        child: ListView(
          children: [
            Card(
              color: context.appColors.customersAccentSurface,
              child: ListTile(
                leading: Icon(
                  Icons.menu_book,
                  color: context.colorScheme.primary,
                ),
                title: Text(l10n.customerFormHeading),
                subtitle: Text(l10n.customerFormDescription),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: AppSpacing.customersCardPadding,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.contacts_outlined),
                  label: Text(l10n.customerImport),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  children: [
                    AppTextField(
                      key: const ValueKey('customer-name'),
                      label: l10n.customerName,
                      controller: _name,
                      isRequired: true,
                      hintText: l10n.customerNameHint,
                      prefix: const Icon(Icons.person_outline),
                    ),
                    SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const ValueKey('customer-phone'),
                      label: l10n.customerPhone,
                      controller: _phone,
                      hintText: l10n.customerPhoneHint,
                      keyboardType: TextInputType.phone,
                      prefix: const Icon(Icons.phone_outlined),
                    ),
                    SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const ValueKey('customer-notes'),
                      label: l10n.customerNotes,
                      controller: _notes,
                      hintText: l10n.customerNotesHint,
                      maxLines: 3,
                      prefix: const Icon(Icons.edit_note),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.customerSave),
            ),
          ],
        ),
      ),
    );
  }
}
