import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/date_service.dart';
import '../../../../core/utils/app_date_utils.dart';

class TransactionDateCard extends StatelessWidget {
  const TransactionDateCard({
    super.key,
    required this.date,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      enabled: enabled,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(context.l10n.transactionDate),
      subtitle: Text(
        AppDateUtils.formatDate(
          date,
          locale: Localizations.localeOf(context).languageCode,
        ),
      ),
      trailing: Text(context.l10n.transactionChange),
      onTap: !enabled
          ? null
          : () async {
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
