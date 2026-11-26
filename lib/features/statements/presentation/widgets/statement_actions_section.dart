import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../domain/formatters/statement_formatter.dart';
import '../cubit/statement_cubit.dart';

class StatementActionsSection extends StatelessWidget {
  const StatementActionsSection({super.key, required this.state});

  final StatementState state;

  Future<void> _copy(BuildContext context) async {
    final cubit = context.read<StatementCubit>();
    if (cubit.state.loading ||
        cubit.state.failure != null ||
        cubit.state.statement == null) {
      return;
    }
    final snapshot = cubit.state.statement!;
    final locale = Localizations.localeOf(context).languageCode;
    var succeeded = false;
    try {
      await Clipboard.setData(
        ClipboardData(
          text: StatementFormatter.format(snapshot, locale: locale),
        ),
      );
      succeeded = true;
    } catch (_) {
      // Platform errors may contain statement text; do not log them.
    }
    if (!context.mounted || cubit.state.statement != snapshot) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                ? context.l10n.statementCopied
                : context.l10n.statementCopyError,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BlocSelector<
        StatementCubit,
        StatementState,
        ({bool enabled, StatementShareStatus shareStatus})
      >(
        selector: (state) =>
            (enabled: state.canShare, shareStatus: state.shareStatus),
        builder: (buttonContext, action) {
          final isGenerating =
              action.shareStatus == StatementShareStatus.generating;
          final isHandingOff =
              action.shareStatus == StatementShareStatus.handingOff;
          final isPending = isGenerating || isHandingOff;
          final label = isGenerating
              ? context.l10n.statementGenerating
              : isHandingOff
              ? context.l10n.statementHandingOff
              : context.l10n.statementImageShare;
          return FilledButton.icon(
            key: const ValueKey('statement-whatsapp'),
            onPressed: action.enabled
                ? () {
                    final box = buttonContext.findRenderObject()! as RenderBox;
                    context.read<StatementCubit>().shareViaSystem(
                      locale: Localizations.localeOf(context).languageCode,
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size,
                    );
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: context.appColors.whatsappColor,
              foregroundColor: context.appColors.onWhatsappColor,
              minimumSize: Size.fromHeight(AppSpacing.statementActionHeight),
            ),
            icon: isPending
                ? DaftariLoading.inline(
                    size: AppSpacing.iconSmall,
                    color: context.colorScheme.primary,
                  )
                : const Icon(Icons.share_outlined),
            label: Text(label),
          );
        },
      ),
      SizedBox(height: AppSpacing.sm),
      FilledButton.tonalIcon(
        key: const ValueKey('statement-copy'),
        onPressed:
            !state.loading && state.failure == null && state.statement != null
            ? () => _copy(context)
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: context.appColors.customersAccentSurface,
          foregroundColor: context.colorScheme.onSurface,
          minimumSize: Size.fromHeight(AppSpacing.statementActionHeight),
        ),
        icon: const Icon(Icons.copy_outlined),
        label: Text(context.l10n.statementCopy),
      ),
      SizedBox(height: AppSpacing.compact),
      Text(
        context.l10n.statementShareHint,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall,
      ),
      SizedBox(height: AppSpacing.md),
    ],
  );
}
