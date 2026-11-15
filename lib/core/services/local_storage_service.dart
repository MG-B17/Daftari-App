import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exception.dart';

/// Non-sensitive preferences only; never use this for customer data or secrets.
class LocalStorageService {
  const LocalStorageService(this._preferences);

  final SharedPreferences _preferences;

  static const _localeKey = 'localeCode';
  static const _themeKey = 'themeMode';
  static const _onboardingKey = 'onboardingCompleted';

  String get localeCode {
    final value = _read(_localeKey);
    return value == 'en' ? 'en' : 'ar';
  }

  ThemeMode get themeMode => switch (_read(_themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  bool get onboardingCompleted => _read(_onboardingKey) == true;

  Future<void> setLocaleCode(String value) async {
    if (value != 'ar' && value != 'en') throw const ValidationException();
    await _write(() => _preferences.setString(_localeKey, value));
  }

  Future<void> setThemeMode(ThemeMode value) =>
      _write(() => _preferences.setString(_themeKey, value.name));

  Future<void> setOnboardingCompleted(bool value) =>
      _write(() => _preferences.setBool(_onboardingKey, value));

  Object? _read(String key) {
    try {
      return _preferences.get(key);
    } catch (_) {
      throw const StorageException();
    }
  }

  Future<void> _write(Future<bool> Function() operation) async {
    try {
      if (!await operation()) throw const StorageException();
    } catch (_) {
      throw const StorageException();
    }
  }
}
