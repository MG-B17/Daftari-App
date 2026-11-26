import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
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
  final _formKey = GlobalKey<FormState>();
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

  void _submit() {
    if (widget.saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<CustomerFormCubit>().save(
      name: _name.text,
      phone: _phone.text,
      notes: _notes.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Card(
            key: const ValueKey('customer-form-header-card'),
            margin: EdgeInsets.zero,
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
            margin: EdgeInsets.zero,
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
            key: const ValueKey('customer-form-fields-card'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                children: [
                  AppTextField(
                    key: const ValueKey('customer-name'),
                    label: l10n.customerName,
                    controller: _name,
                    isRequired: true,
                    enabled: !widget.saving,
                    hintText: l10n.customerNameHint,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.person_outline),
                    validator: (value) =>
                        Validators.customerName(value, locale: locale),
                  ),
                  SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const ValueKey('customer-phone'),
                    label: l10n.customerPhone,
                    controller: _phone,
                    enabled: !widget.saving,
                    hintText: l10n.customerPhoneHint,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.phone_outlined),
                    validator: (value) =>
                        Validators.egyptianMobile(value, locale: locale),
                  ),
                  SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const ValueKey('customer-notes'),
                    label: l10n.customerNotes,
                    controller: _notes,
                    enabled: !widget.saving,
                    hintText: l10n.customerNotesHint,
                    maxLines: 3,
                    prefix: const Icon(Icons.edit_note),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const ValueKey('customer-save'),
            label: l10n.customerSave,
            icon: Icons.person_add_alt,
            fullWidth: true,
            isLoading: widget.saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
