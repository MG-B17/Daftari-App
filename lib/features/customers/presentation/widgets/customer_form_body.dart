import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/picked_contact.dart';
import '../cubit/customer_form_cubit.dart';
import '../customer_error_message.dart';

class CustomerFormBody extends StatefulWidget {
  const CustomerFormBody({
    super.key,
    this.customer,
    this.initialContact,
    this.saving = false,
  });

  final CustomerEntity? customer;
  final PickedContact? initialContact;
  final bool saving;

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
    _name = TextEditingController(
      text: widget.customer?.name ?? widget.initialContact?.name,
    );
    _phone = TextEditingController(
      text: widget.customer?.phone ?? widget.initialContact?.phone,
    );
    _notes = TextEditingController(text: widget.customer?.notes);
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
                  onPressed: widget.saving
                      ? null
                      : () async {
                          final result = await context
                              .read<CustomerFormCubit>()
                              .pickContact();
                          if (!context.mounted) return;
                          result.fold(
                            (failure) => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      customerErrorMessage(
                                        context,
                                        failure.errorCode,
                                      ),
                                    ),
                                  ),
                                ),
                            (contact) {
                              if (contact != null) {
                                if (contact.name != null) {
                                  _name.text = contact.name!;
                                }
                                if (contact.phone != null) {
                                  _phone.text = contact.phone!;
                                }
                              }
                            },
                          );
                        },
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
              onPressed: widget.saving
                  ? null
                  : () => context.read<CustomerFormCubit>().save(
                      name: _name.text,
                      phone: _phone.text,
                      notes: _notes.text,
                    ),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.customerSave),
            ),
          ],
        ),
      ),
    );
  }
}
