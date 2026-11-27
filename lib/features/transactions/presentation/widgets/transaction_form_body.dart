import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/date/date_service.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/amount_input_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_form_cubit.dart';
import 'transaction_amount_card.dart';
import 'transaction_customer_card.dart';
import 'transaction_date_card.dart';
import 'transaction_keypad.dart';
import 'transaction_type_toggle.dart';

class TransactionFormBody extends StatefulWidget {
  const TransactionFormBody({
    super.key,
    this.customerId,
    this.initialType,
    this.transactionId,
    this.isEdit = false,
  });

  final String? customerId;
  final String? initialType;
  final String? transactionId;
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
  String? customerError;
  String? amountError;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void input(String key) {
    setState(() {
      amount = AmountInputUtils.applyKeypadInput(amount, key);
      final parsed = AmountInputUtils.tryParseInputToPiasters(amount);
      if (amountError != null && parsed != null && parsed > 0) {
        amountError = null;
      }
    });
  }

  void add(int value) {
    setState(() {
      amount = AmountInputUtils.addEgp(amount, value);
      final parsed = AmountInputUtils.tryParseInputToPiasters(amount);
      if (amountError != null && parsed != null && parsed > 0) {
        amountError = null;
      }
    });
  }

  void _submit(TransactionFormState state) {
    if (state.saving || state.saved) return;
    FocusScope.of(context).unfocus();
    final hasCustomer =
        customerId != null && state.customers.any((c) => c.id == customerId);
    final parsed = AmountInputUtils.tryParseInputToPiasters(amount);
    final hasValidAmount = parsed != null && parsed > 0;
    if (!hasCustomer || !hasValidAmount) {
      setState(() {
        customerError = hasCustomer
            ? null
            : context.l10n.transactionCustomerRequired;
        amountError = hasValidAmount
            ? null
            : context.l10n.transactionAmountRequired;
      });
      return;
    }
    if (customerError != null || amountError != null) {
      setState(() {
        customerError = null;
        amountError = null;
      });
    }
    context.read<TransactionFormCubit>().save(
      customerId: customerId,
      type: payment ? TransactionType.payment : TransactionType.credit,
      amount: amount,
      date: date,
      note: note.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionFormCubit, TransactionFormState>(
          listenWhen: (previous, current) =>
              previous.transaction != current.transaction &&
              current.transaction != null,
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
                customerError = null;
                amountError = null;
              });
            }
          },
        ),
        BlocListener<TransactionFormCubit, TransactionFormState>(
          listenWhen: (previous, current) =>
              previous.submissionId != current.submissionId &&
              (current.saved || current.submissionFailure != null),
          listener: (context, state) async {
            if (state.saved) {
              final l10n = context.l10n;
              final isPayment =
                  (state.savedType ??
                      (payment
                          ? TransactionType.payment
                          : TransactionType.credit)) ==
                  TransactionType.payment;
              final (title, message, assetPath) = widget.isEdit
                  ? (
                      l10n.transactionUpdatedTitle,
                      l10n.transactionUpdatedMessage,
                      AppSuccessDialog.defaultAssetPath,
                    )
                  : isPayment
                  ? (
                      l10n.transactionPaymentAddedTitle,
                      l10n.transactionPaymentAddedMessage,
                      AppSuccessDialog.debtPaidAssetPath,
                    )
                  : (
                      l10n.transactionCreditAddedTitle,
                      l10n.transactionCreditAddedMessage,
                      AppSuccessDialog.transactionAddedAssetPath,
                    );
              await AppSuccessDialog.show(
                context,
                title: title,
                message: message,
                assetPath: assetPath,
              );
              if (!context.mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.customers);
              }
            } else if (state.submissionFailure != null) {
              await AppErrorDialog.show(
                context,
                message: context.l10n.transactionSaveError,
              );
            }
          },
        ),
      ],
      child: BlocBuilder<TransactionFormCubit, TransactionFormState>(
        builder: (context, state) {
          if (state.loading) {
            return const DaftariLoading.screen();
          }
          if (widget.isEdit && state.transaction == null) {
            if (state.failure != null &&
                state.failure!.errorCode != AppErrorCode.validation &&
                widget.transactionId != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.transactionHistoryError),
                    TextButton(
                      onPressed: () => context
                          .read<TransactionFormCubit>()
                          .load(widget.transactionId),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }
            return Center(child: Text(l10n.transactionNotFound));
          }
          final matches = state.customers.where((c) => c.id == customerId);
          final selectedCustomer = matches.isEmpty ? null : matches.first;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppSpacing.customersMaxWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        TransactionTypeToggle(
                          payment: payment,
                          enabled: !state.saving,
                          onChanged: (value) => setState(() => payment = value),
                        ),
                        SizedBox(height: AppSpacing.md),
                        TransactionCustomerCard(
                          customers: state.customers,
                          selected: selectedCustomer,
                          enabled: !widget.isEdit && !state.saving,
                          onChanged: (id) => setState(() {
                            customerId = id;
                            customerError = null;
                          }),
                        ),
                        if (customerError != null)
                          Padding(
                            key: const ValueKey('transaction-customer-error'),
                            padding: EdgeInsetsDirectional.only(
                              start: AppSpacing.md,
                              top: AppSpacing.xs,
                            ),
                            child: Text(
                              customerError!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.error,
                              ),
                            ),
                          ),
                        SizedBox(height: AppSpacing.sm),
                        TransactionAmountCard(
                          amount: amount,
                          payment: payment,
                          enabled: !state.saving,
                          onAdd: add,
                        ),
                        if (amountError != null)
                          Padding(
                            key: const ValueKey('transaction-amount-error'),
                            padding: EdgeInsetsDirectional.only(
                              start: AppSpacing.md,
                              top: AppSpacing.xs,
                            ),
                            child: Text(
                              amountError!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.error,
                              ),
                            ),
                          ),
                        SizedBox(height: AppSpacing.sm),
                        TransactionDateCard(
                          date: date,
                          enabled: !state.saving,
                          onChanged: (value) => setState(() => date = value),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: note,
                          enabled: !state.saving,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.edit_note),
                            hintText: l10n.transactionNote,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        TransactionKeypad(
                          onInput: input,
                          enabled: !state.saving,
                        ),
                        SizedBox(height: AppSpacing.md),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  AppButton(
                    key: const ValueKey('transaction-save'),
                    label: l10n.transactionSave,
                    icon: Icons.check_circle_outline,
                    fullWidth: true,
                    isLoading: state.saving,
                    onPressed: () => _submit(state),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
