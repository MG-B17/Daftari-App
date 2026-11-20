import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/statement_date_range.dart';
import '../cubit/statement_cubit.dart';

class StatementRangeFilter extends StatelessWidget {
  const StatementRangeFilter({
    super.key,
    required this.range,
    required this.generatedAt,
  });

  final StatementDateRange range;
  final DateTime generatedAt;

  Future<void> _customRange(BuildContext context) async {
    final cubit = context.read<StatementCubit>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: generatedAt,
      builder: (context, child) => Theme(
        data: context.theme.copyWith(
          datePickerTheme: DatePickerTheme.of(context).copyWith(
            rangePickerHeaderHeadlineStyle: context.textTheme.titleMedium,
          ),
        ),
        child: child!,
      ),
      initialDateRange: range.type == StatementDateRangeType.custom
          ? DateTimeRange(start: range.start!, end: range.end!)
          : null,
    );
    if (!context.mounted || picked == null) return;
    await cubit.setRange(
      StatementDateRange.custom(start: picked.start, end: picked.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (index, label) in [
              l10n.statementRangeAll,
              l10n.statementRangeLast30Days,
              l10n.statementRangeThisMonth,
              l10n.statementRangeCustom,
            ].indexed)
              ChoiceChip(
                label: Text(label),
                key: ValueKey('statement-range-$index'),
                selected: range.type.index == index,
                onSelected: (_) {
                  if (index == 3) {
                    _customRange(context);
                  } else {
                    context.read<StatementCubit>().setRange(
                      [
                        StatementDateRange.all,
                        StatementDateRange.last30Days,
                        StatementDateRange.thisMonth,
                      ][index],
                    );
                  }
                },
              ),
          ],
        ),
        if (range.type == StatementDateRangeType.custom)
          Text(
            '${AppDateUtils.formatDate(range.start!, locale: locale)}'
            ' – ${AppDateUtils.formatDate(range.end!, locale: locale)}',
          ),
      ],
    );
  }
}
