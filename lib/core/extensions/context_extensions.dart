import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_color_scheme.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  AppColorScheme get appColors => theme.extension<AppColorScheme>()!;
  TextTheme get textTheme => theme.textTheme;
}
