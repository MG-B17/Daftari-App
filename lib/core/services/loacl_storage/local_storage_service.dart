import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../errors/app_exception.dart';

/// Non-sensitive preferences only; never use this for customer data or secrets.
class LocalStorageService {
  LocalStorageService(this._preferences);

  final SharedPreferences _preferences;

  static final Expando<_PreferenceJournal> _journals =
      Expando<_PreferenceJournal>('LocalStorageServiceJournal');

  _PreferenceJournal get _journal =>
      _journals[_preferences] ??= _PreferenceJournal();

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
    await _write(
      _securityRevisionKey,
      revision,
      () => _preferences.setInt(_securityRevisionKey, revision),
    );
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

  Future<void> markSecurityInitialized() => _write(
    _securityInitializedKey,
    true,
    () => _preferences.setBool(_securityInitializedKey, true),
  );

  Future<void> setSecurityAutoLockTimeout(String value) async {
    if (!['immediate', 'oneMinute', 'fiveMinutes'].contains(value)) {
      throw const ValidationException();
    }
    await _write(
      _autoLockKey,
      value,
      () => _preferences.setString(_autoLockKey, value),
    );
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
    await _write(
      _localeKey,
      value,
      () => _preferences.setString(_localeKey, value),
    );
  }

  Future<void> setThemeMode(ThemeMode value) => _write(
    _themeKey,
    value.name,
    () => _preferences.setString(_themeKey, value.name),
  );

  Future<void> setOnboardingCompleted(bool value) => _write(
    _onboardingKey,
    value,
    () => _preferences.setBool(_onboardingKey, value),
  );

  Object? _read(String key) {
    final Object? cached;
    try {
      cached = _preferences.get(key);
    } catch (_) {
      throw const StorageException();
    }
    final journal = _journal;
    if (journal.confirmedValues.containsKey(key)) {
      return journal.confirmedValues[key];
    }
    return cached;
  }

  Future<void> _write<T>(
    String key,
    T value,
    Future<bool> Function() operation,
  ) async {
    final journal = _journal;
    if ((journal.inFlight[key] ?? 0) == 0 &&
        !journal.confirmedValues.containsKey(key)) {
      try {
        journal.confirmedValues[key] = _preferences.get(key);
      } catch (_) {}
    }
    final seq = (journal.writeSeq[key] ?? 0) + 1;
    journal.writeSeq[key] = seq;
    journal.inFlight[key] = (journal.inFlight[key] ?? 0) + 1;
    journal.globalWriteSeq++;

    var succeeded = false;
    try {
      succeeded = await operation();
    } catch (_) {
      succeeded = false;
    }

    journal.inFlight[key] = (journal.inFlight[key] ?? 1) - 1;
    journal.globalWriteSeq++;

    if (succeeded) {
      if (seq > (journal.confirmedSeq[key] ?? 0)) {
        journal.confirmedSeq[key] = seq;
        journal.confirmedValues[key] = value;
      }
      if (seq < (journal.writeSeq[key] ?? 0)) {
        journal.needsReload.add(key);
      }
      if ((journal.inFlight[key] ?? 0) == 0) {
        if (journal.needsReload.contains(key)) {
          await _reconcileKey(key);
        } else {
          journal.confirmedValues.remove(key);
        }
      }
      return;
    }

    journal.needsReload.add(key);
    if ((journal.inFlight[key] ?? 0) == 0) {
      await _reconcileKey(key);
    }
    throw const StorageException();
  }

  Future<void> _reconcileKey(String key) async {
    final journal = _journal;
    final seqBefore = journal.writeSeq[key];
    final reloaded = await _reloadSafely();
    if (!reloaded ||
        (journal.inFlight[key] ?? 0) != 0 ||
        journal.writeSeq[key] != seqBefore) {
      return;
    }
    try {
      if (_preferences.get(key) == journal.confirmedValues[key]) {
        journal.needsReload.remove(key);
        journal.confirmedValues.remove(key);
      }
    } catch (_) {
      // Keep the last acknowledged value pinned if reading the cache fails.
    }
  }

  Future<bool> _reloadSafely() {
    final journal = _journal;
    journal.reloadRequested = true;
    return journal.reloadLoop ??= _drainReloads(journal);
  }

  Future<bool> _drainReloads(_PreferenceJournal journal) async {
    var allSucceeded = true;
    try {
      while (journal.reloadRequested) {
        journal.reloadRequested = false;
        for (final entry in journal.inFlight.entries) {
          if (entry.value > 0) journal.needsReload.add(entry.key);
        }
        final versionBefore = journal.globalWriteSeq;
        try {
          await _preferences.reload();
        } catch (_) {
          allSucceeded = false;
          continue;
        }
        if (journal.globalWriteSeq != versionBefore) {
          journal.reloadRequested = true;
        }
      }
      return allSucceeded;
    } finally {
      journal.reloadLoop = null;
    }
  }
}

final class _PreferenceJournal {
  final Map<String, int> writeSeq = {};
  final Map<String, int> confirmedSeq = {};
  final Map<String, int> inFlight = {};
  final Map<String, Object?> confirmedValues = {};
  final Set<String> needsReload = {};
  int globalWriteSeq = 0;
  Future<bool>? reloadLoop;
  bool reloadRequested = false;
}
