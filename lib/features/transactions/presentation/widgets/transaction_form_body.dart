import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/date_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/amount_input_utils.dart';
import '../../../../core/routing/app_routes.dart';
import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_form_cubit.dart';
import 'transaction_keypad.dart';
import 'transaction_type_toggle.dart';
import 'transaction_customer_card.dart';
import 'transaction_amount_card.dart';
import 'transaction_date_card.dart';

class TransactionFormBody extends StatefulWidget {
  const TransactionFormBody({
    super.key,
    this.customerId,
    this.initialType,
    this.isEdit = false,
  });

  final String? customerId;
  final String? initialType;
  final bool isEdit;

  @override
  State<TransactionFormBody> createState() => _TransactionFormBodyState();
}

class _TransactionFormBodyState extends State<TransactionFormBody> {
  late bool payment = widget.initialType == 'payment';
  String amount = '0';
  late DateTime date = sl<DateService>().now();
  late String? customerId = widget.customerId;
  final note = TextEditingController();
  bool loadedEdit = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void input(String key) {
    setState(() => amount = AmountInputUtils.applyKeypadInput(amount, key));
  }

  void add(int value) {
    setState(() => amount = AmountInputUtils.addEgp(amount, value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (previous, current) =>
          (current.failure != null && previous.failure != current.failure) ||
          (current.failure == null &&
              (previous.transaction != current.transaction ||
                  previous.saved != current.saved)),
      listener: (context, state) {
        final transaction = state.transaction;
        if (transaction != null && !loadedEdit) {
          loadedEdit = true;
          setState(() {
            customerId = transaction.customerId;
            payment = transaction.type == TransactionType.payment;
            amount = AmountInputUtils.formatEditablePiasters(
              transaction.amountPiasters,
            );
            date = transaction.transactionDate;
            note.text = transaction.note ?? '';
          });
        }
        if (state.saved) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.customers);
          }
        } else if (state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.transactionSaveError)),
          );
        }
      },
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.isEdit && state.transaction == null) {
          return Center(child: Text(l10n.transactionNotFound));
        }
        final matches = state.customers.where((c) => c.id == customerId);
        final selectedCustomer = matches.isEmpty ? null : matches.first;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSpacing.customersMaxWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      TransactionTypeToggle(
                        payment: payment,
                        onChanged: (value) => setState(() => payment = value),
                      ),
                      SizedBox(height: AppSpacing.md),
                      TransactionCustomerCard(
                        customers: state.customers,
                        selected: selectedCustomer,
                        enabled: !widget.isEdit && !state.saving,
                        onChanged: (id) => setState(() => customerId = id),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TransactionAmountCard(
                        amount: amount,
                        payment: payment,
                        onAdd: add,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TransactionDateCard(
                        date: date,
                        onChanged: (value) => setState(() => date = value),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: note,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.edit_note),
                          hintText: l10n.transactionNote,
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      TransactionKeypad(onInput: input),
                      SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.saving
                        ? null
                        : () => context.read<TransactionFormCubit>().save(
                            customerId: customerId,
                            type: payment
                                ? TransactionType.payment
                                : TransactionType.credit,
                            amount: amount,
                            date: date,
                            note: note.text,
                          ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l10n.transactionSave),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
