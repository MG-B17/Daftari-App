import 'package:flutter/material.dart' show ThemeMode;

import '../repositories/settings_repository.dart';

/// Persists a new appearance preference.
class ChangeThemeUseCase {
  const ChangeThemeUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(ThemeMode themeMode) => _repository.setThemeMode(themeMode);
}
