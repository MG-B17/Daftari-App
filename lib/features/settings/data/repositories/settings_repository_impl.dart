import 'package:flutter/material.dart' show ThemeMode;

import '../../../../core/services/local_storage_service.dart';
import '../../domain/repositories/settings_repository.dart';

/// [SettingsRepository] backed by [LocalStorageService].
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._localStorage);

  final LocalStorageService _localStorage;

  @override
  String get localeCode => _localStorage.localeCode;

  @override
  ThemeMode get themeMode => _localStorage.themeMode;

  @override
  Future<void> setLocaleCode(String localeCode) =>
      _localStorage.setLocaleCode(localeCode);

  @override
  Future<void> setThemeMode(ThemeMode themeMode) =>
      _localStorage.setThemeMode(themeMode);
}
