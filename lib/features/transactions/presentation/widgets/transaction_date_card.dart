import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/date_service.dart';
import '../../../../core/utils/app_date_utils.dart';

class TransactionDateCard extends StatelessWidget {
  const TransactionDateCard({
    super.key,
    required this.date,
    required this.onChanged,
  });
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(context.l10n.transactionDate),
      subtitle: Text(
        AppDateUtils.formatDate(
          date,
          locale: Localizations.localeOf(context).languageCode,
        ),
      ),
      trailing: Text(context.l10n.transactionChange),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1900),
          lastDate: sl<DateService>().now(),
        );
        if (selected != null && context.mounted) onChanged(selected);
      },
    ),
  );
}
