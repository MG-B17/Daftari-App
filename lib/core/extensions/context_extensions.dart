import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/colors/app_color_scheme.dart';
import '../utils/money_utils.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  AppColorScheme get appColors => theme.extension<AppColorScheme>()!;
  TextTheme get textTheme => theme.textTheme;

  /// Formats piasters for the active locale (Western digits plus the locale's
  /// currency label, matching the approved money design).
  String formatMoney(int piasters) => MoneyUtils.formatPiasters(
    piasters,
    locale: Localizations.localeOf(this).languageCode,
  );
}
