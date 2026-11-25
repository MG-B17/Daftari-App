import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../../auth/session/presentation/cubit/auth_session_state.dart';
import '../cubit/restore_cubit.dart';
import '../cubit/restore_state.dart';

extension RestoreDateFormatting on DateTime {
  String confirmedAtLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return context.l10n
        .restoreConfirmedAt(
          AppDateUtils.relativeDay(this, locale: locale),
          AppDateUtils.formatTime(this, locale: locale),
        )
        .toWesternDigits;
  }
}

/// Resolves an explicit [state], an active [RestoreCubit], or a safe default
/// preview state reflecting [AuthSessionCubit] when available.
class RestoreViewStateBuilder extends StatelessWidget {
  const RestoreViewStateBuilder({
    super.key,
    required this.state,
    required this.builder,
  });

  final RestoreViewState? state;
  final Widget Function(BuildContext context, RestoreViewState view) builder;

  @override
  Widget build(BuildContext context) {
    if (state case final fixed?) return builder(context, fixed);
    final restoreCubit = context.read<RestoreCubit?>();
    if (restoreCubit != null) {
      return BlocBuilder<RestoreCubit, RestoreViewState>(
        builder: (context, view) {
          if (view.phase == RestorePhase.initial) {
            unawaited(context.read<RestoreCubit>().loadPreview());
          }
          return builder(context, view);
        },
      );
    }
    final authCubit = context.read<AuthSessionCubit?>();
    if (authCubit == null) {
      return builder(context, RestoreViewState.preview());
    }
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      builder: (context, authState) => builder(
        context,
        RestoreViewState.preview(
          user:
              authState.isAuthenticated ||
                  authState.status == AuthStatus.emailVerificationRequired
              ? authState.user
              : null,
        ),
      ),
    );
  }
}
