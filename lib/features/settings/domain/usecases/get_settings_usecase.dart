import 'package:flutter/material.dart' show ThemeMode;

import '../repositories/settings_repository.dart';

/// Snapshot of the persisted settings consumed by the presentation layer.
typedef SettingsSnapshot = ({String localeCode, ThemeMode themeMode});

/// Reads the persisted language and appearance preferences.
class GetSettingsUseCase {
  const GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  SettingsSnapshot call() =>
      (localeCode: _repository.localeCode, themeMode: _repository.themeMode);
}
