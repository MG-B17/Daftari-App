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
  static const _securityInitializedKey = 'securityInitialized';
  static const _autoLockKey = 'securityAutoLockTimeout';
  static const _securityRevisionKey = 'securityRevision';

  int get securityRevision {
    final value = _read(_securityRevisionKey);
    if (value == null) return 0;
    if (value is! int || value < 0) throw const StorageException();
    return value;
  }

  Future<void> setSecurityRevision(int revision) async {
    if (revision < 1) throw const ValidationException();
    await _write(() => _preferences.setInt(_securityRevisionKey, revision));
  }

  bool get securityInitialized {
    final value = _read(_securityInitializedKey);
    if (value != null && value is! bool) throw const StorageException();
    return value == true;
  }

  String get securityAutoLockTimeout => switch (_read(_autoLockKey)) {
    'oneMinute' => 'oneMinute',
    'fiveMinutes' => 'fiveMinutes',
    _ => 'immediate',
  };

  Future<void> markSecurityInitialized() =>
      _write(() => _preferences.setBool(_securityInitializedKey, true));

  Future<void> setSecurityAutoLockTimeout(String value) async {
    if (!['immediate', 'oneMinute', 'fiveMinutes'].contains(value)) {
      throw const ValidationException();
    }
    await _write(() => _preferences.setString(_autoLockKey, value));
  }

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
