import 'dart:async';

import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_state.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controllable platform store behind the real legacy [SharedPreferences]
/// method channel so tests exercise the exact in-memory cache behavior of
/// `shared_preferences`.
class _ControllablePlatformPrefsStore {
  _ControllablePlatformPrefsStore([
    Map<String, Object>? initial,
    this.simulateAndroidMemoryFirstCommit = false,
  ]) : data = Map<String, Object>.from(initial ?? const {}),
       nativeMemory = Map<String, Object>.from(initial ?? const {});

  static const _channel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );

  /// Durable disk-backed values.
  final Map<String, Object> data;

  /// Process-local native memory map (Android `SharedPreferencesImpl.mMap`).
  final Map<String, Object> nativeMemory;

  /// When true, mirrors Android's `SharedPreferencesImpl.commit()` behavior:
  /// updates [nativeMemory] before the disk write completes and serves `getAll`
  /// from [nativeMemory] even when the disk commit returns `false`.
  final bool simulateAndroidMemoryFirstCommit;

  Future<bool> Function(String key, Object value)? onSet;

  void install() {
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handleCall);
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  }

  Future<Object?> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        return Map<String, Object>.from(
          simulateAndroidMemoryFirstCommit ? nativeMemory : data,
        );
      case 'setString':
      case 'setBool':
      case 'setInt':
      case 'setDouble':
      case 'setStringList':
        final args = Map<String, Object?>.from(call.arguments as Map);
        final key = args['key']! as String;
        final value = args['value']!;
        if (simulateAndroidMemoryFirstCommit) {
          nativeMemory[key] = value;
        }
        final handler = onSet;
        if (handler != null) {
          final stored = await handler(key, value);
          if (stored) {
            data[key] = value;
            nativeMemory[key] = value;
          }
          return stored;
        }
        data[key] = value;
        nativeMemory[key] = value;
        return true;
      case 'remove':
        final args = Map<String, Object?>.from(call.arguments as Map);
        final key = args['key']! as String;
        data.remove(key);
        nativeMemory.remove(key);
        return true;
      case 'clear':
        data.clear();
        nativeMemory.clear();
        return true;
      default:
        throw MissingPluginException('Unhandled method: ${call.method}');
    }
  }
}

ErrorHandler _errorHandler() =>
    ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false));

SettingsCubit _createSettingsCubit(LocalStorageService storage) {
  final repo = SettingsRepositoryImpl(storage);
  return SettingsCubit(
    GetSettingsUseCase(repo),
    ChangeLanguageUseCase(repo),
    _errorHandler(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failureMode in ['returnFalse', 'throwException']) {
    test(
      'P15-06 theme ($failureMode): failed write keeps active Cubit, direct service read, new Cubit, and platform store aligned on last persisted mode',
      () async {
        final store = _ControllablePlatformPrefsStore();
        store.install();
        addTearDown(store.uninstall);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final cubit = ThemeSwitcherCubit(storage, _errorHandler());
        addTearDown(cubit.close);

        // First write succeeds -> dark is persisted.
        await cubit.setThemeMode(ThemeMode.dark);
        expect(
          cubit.state,
          const ThemeSwitcherState(themeMode: ThemeMode.dark),
        );
        expect(storage.themeMode, ThemeMode.dark);
        expect(store.data['flutter.themeMode'], 'dark');

        // Next write fails (returns false or throws).
        store.onSet = (key, value) async {
          if (failureMode == 'returnFalse') return false;
          throw PlatformException(code: 'write_failed');
        };

        await cubit.setThemeMode(ThemeMode.light);

        final newCubitSameService = ThemeSwitcherCubit(
          storage,
          _errorHandler(),
        );
        final newCubitFreshService = ThemeSwitcherCubit(
          LocalStorageService(prefs),
          _errorHandler(),
        );
        addTearDown(newCubitSameService.close);
        addTearDown(newCubitFreshService.close);

        expect(
          cubit.state,
          const ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: true),
        );
        expect(storage.themeMode, ThemeMode.dark);
        expect(LocalStorageService(prefs).themeMode, ThemeMode.dark);
        expect(newCubitSameService.state.themeMode, ThemeMode.dark);
        expect(newCubitFreshService.state.themeMode, ThemeMode.dark);
        expect(store.data['flutter.themeMode'], 'dark');
      },
    );

    test(
      'P15-06 language ($failureMode): failed write keeps active Cubit, direct service read, new Cubit, and platform store aligned on last persisted locale',
      () async {
        final store = _ControllablePlatformPrefsStore();
        store.install();
        addTearDown(store.uninstall);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final cubit = _createSettingsCubit(storage);
        addTearDown(cubit.close);

        // First write succeeds -> English is persisted.
        await cubit.setLocaleCode('en');
        expect(cubit.state, const SettingsState(localeCode: 'en'));
        expect(storage.localeCode, 'en');
        expect(store.data['flutter.localeCode'], 'en');

        // Next write to Arabic fails (returns false or throws).
        store.onSet = (key, value) async {
          if (failureMode == 'returnFalse') return false;
          throw PlatformException(code: 'write_failed');
        };

        await cubit.setLocaleCode('ar');

        final newCubitSameService = _createSettingsCubit(storage);
        final newCubitFreshService = _createSettingsCubit(
          LocalStorageService(prefs),
        );
        addTearDown(newCubitSameService.close);
        addTearDown(newCubitFreshService.close);

        expect(
          cubit.state,
          const SettingsState(localeCode: 'en', hasError: true),
        );
        expect(storage.localeCode, 'en');
        expect(LocalStorageService(prefs).localeCode, 'en');
        expect(newCubitSameService.state.localeCode, 'en');
        expect(newCubitFreshService.state.localeCode, 'en');
        expect(store.data['flutter.localeCode'], 'en');
      },
    );

    test(
      'P15-06 overlapping theme ($failureMode): earlier write succeeds and later write fails -> all readers agree on earlier persisted mode',
      () async {
        final store = _ControllablePlatformPrefsStore();
        store.install();
        addTearDown(store.uninstall);

        final darkWrite = Completer<bool>();
        final lightWrite = Completer<bool>();
        store.onSet = (key, value) {
          if (value == 'dark') return darkWrite.future;
          if (value == 'light') return lightWrite.future;
          return Future<bool>.value(true);
        };

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final cubit = ThemeSwitcherCubit(storage, _errorHandler());
        addTearDown(cubit.close);

        final darkCall = cubit.setThemeMode(ThemeMode.dark);
        final lightCall = cubit.setThemeMode(ThemeMode.light);

        darkWrite.complete(true);
        await darkCall;
        expect(storage.themeMode, ThemeMode.dark);

        if (failureMode == 'returnFalse') {
          lightWrite.complete(false);
        } else {
          lightWrite.completeError(PlatformException(code: 'write_failed'));
        }
        await lightCall;

        final newCubit = ThemeSwitcherCubit(
          LocalStorageService(prefs),
          _errorHandler(),
        );
        addTearDown(newCubit.close);

        expect(
          cubit.state,
          const ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: true),
        );
        expect(storage.themeMode, ThemeMode.dark);
        expect(LocalStorageService(prefs).themeMode, ThemeMode.dark);
        expect(newCubit.state.themeMode, ThemeMode.dark);
        expect(store.data['flutter.themeMode'], 'dark');
      },
    );

    test(
      'P15-06 stale failure ($failureMode): older theme and language failures preserve newer successful selections across all readers',
      () async {
        final store = _ControllablePlatformPrefsStore({
          'flutter.themeMode': 'light',
          'flutter.localeCode': 'ar',
        });
        store.install();
        addTearDown(store.uninstall);

        final staleThemeWrite = Completer<bool>();
        final staleLocaleWrite = Completer<bool>();
        store.onSet = (key, value) {
          if (key == 'flutter.themeMode' && value == 'dark') {
            return staleThemeWrite.future;
          }
          if (key == 'flutter.localeCode' && value == 'en') {
            return staleLocaleWrite.future;
          }
          return Future<bool>.value(true);
        };

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final themeCubit = ThemeSwitcherCubit(storage, _errorHandler());
        final settingsCubit = _createSettingsCubit(storage);
        addTearDown(themeCubit.close);
        addTearDown(settingsCubit.close);

        // Theme: start dark (pending), then select system (succeeds), then fail dark.
        final staleThemeCall = themeCubit.setThemeMode(ThemeMode.dark);
        await themeCubit.setThemeMode(ThemeMode.system);

        if (failureMode == 'returnFalse') {
          staleThemeWrite.complete(false);
        } else {
          staleThemeWrite.completeError(
            PlatformException(code: 'write_failed'),
          );
        }
        await staleThemeCall;

        // Language: start en (pending), then select ar (succeeds), then fail en.
        final staleLocaleCall = settingsCubit.setLocaleCode('en');
        await settingsCubit.setLocaleCode('ar');

        if (failureMode == 'returnFalse') {
          staleLocaleWrite.complete(false);
        } else {
          staleLocaleWrite.completeError(
            PlatformException(code: 'write_failed'),
          );
        }
        await staleLocaleCall;

        final newThemeCubit = ThemeSwitcherCubit(
          LocalStorageService(prefs),
          _errorHandler(),
        );
        final newSettingsCubit = _createSettingsCubit(
          LocalStorageService(prefs),
        );
        addTearDown(newThemeCubit.close);
        addTearDown(newSettingsCubit.close);

        expect(
          themeCubit.state,
          const ThemeSwitcherState(
            themeMode: ThemeMode.system,
            hasError: false,
          ),
        );
        expect(storage.themeMode, ThemeMode.system);
        expect(LocalStorageService(prefs).themeMode, ThemeMode.system);
        expect(newThemeCubit.state.themeMode, ThemeMode.system);
        expect(store.data['flutter.themeMode'], 'system');

        expect(
          settingsCubit.state,
          const SettingsState(localeCode: 'ar', hasError: false),
        );
        expect(storage.localeCode, 'ar');
        expect(LocalStorageService(prefs).localeCode, 'ar');
        expect(newSettingsCubit.state.localeCode, 'ar');
        expect(store.data['flutter.localeCode'], 'ar');
      },
    );
  }

  test('P15-06: older failure settling before a newer pending write succeeds still reconciles to the newer persisted choice', () async {
    final store = _ControllablePlatformPrefsStore({
      'flutter.themeMode': 'light',
      'flutter.localeCode': 'ar',
    });
    store.install();
    addTearDown(store.uninstall);

    final firstThemeWrite = Completer<bool>();
    final secondThemeWrite = Completer<bool>();
    store.onSet = (key, value) {
      if (key == 'flutter.themeMode' && value == 'dark') {
        return firstThemeWrite.future;
      }
      if (key == 'flutter.themeMode' && value == 'system') {
        return secondThemeWrite.future;
      }
      return Future<bool>.value(true);
    };

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final cubit = ThemeSwitcherCubit(storage, _errorHandler());
    addTearDown(cubit.close);

    final firstCall = cubit.setThemeMode(ThemeMode.dark);
    final secondCall = cubit.setThemeMode(ThemeMode.system);

    firstThemeWrite.complete(false);
    await firstCall;

    // Direct reader still sees last confirmed mode while newer write is in flight.
    expect(storage.themeMode, ThemeMode.light);

    secondThemeWrite.complete(true);
    await secondCall;

    final newCubit = ThemeSwitcherCubit(
      LocalStorageService(prefs),
      _errorHandler(),
    );
    addTearDown(newCubit.close);

    expect(
      cubit.state,
      const ThemeSwitcherState(themeMode: ThemeMode.system, hasError: false),
    );
    expect(storage.themeMode, ThemeMode.system);
    expect(LocalStorageService(prefs).themeMode, ThemeMode.system);
    expect(newCubit.state.themeMode, ThemeMode.system);
    expect(store.data['flutter.themeMode'], 'system');
  });

  test('P15-06 Android memory-first commit (language): failed disk commit keeps Arabic across active Cubit, direct service getter, and new Cubit even when reload returns English, then a later successful write updates all readers', () async {
    final store = _ControllablePlatformPrefsStore({
      'flutter.localeCode': 'ar',
    }, true);
    store.install();
    addTearDown(store.uninstall);

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final cubit = _createSettingsCubit(storage);
    addTearDown(cubit.close);

    // Android updates native memory to English before disk commit fails and
    // returns false; durable storage remains Arabic while getAll returns native memory.
    store.onSet = (key, value) async => false;
    await cubit.setLocaleCode('en');

    expect(store.nativeMemory['flutter.localeCode'], 'en');
    expect(store.data['flutter.localeCode'], 'ar');

    final newCubitSameService = _createSettingsCubit(storage);
    final newCubitFreshService = _createSettingsCubit(
      LocalStorageService(prefs),
    );
    addTearDown(newCubitSameService.close);
    addTearDown(newCubitFreshService.close);

    expect(cubit.state, const SettingsState(localeCode: 'ar', hasError: true));
    expect(storage.localeCode, 'ar');
    expect(LocalStorageService(prefs).localeCode, 'ar');
    expect(newCubitSameService.state.localeCode, 'ar');
    expect(newCubitFreshService.state.localeCode, 'ar');

    // A subsequent successful choice becomes visible to all readers.
    store.onSet = null;
    await cubit.setLocaleCode('en');

    final afterSuccessCubit = _createSettingsCubit(LocalStorageService(prefs));
    addTearDown(afterSuccessCubit.close);

    expect(cubit.state, const SettingsState(localeCode: 'en', hasError: false));
    expect(storage.localeCode, 'en');
    expect(LocalStorageService(prefs).localeCode, 'en');
    expect(afterSuccessCubit.state.localeCode, 'en');
    expect(store.data['flutter.localeCode'], 'en');
    expect(store.nativeMemory['flutter.localeCode'], 'en');
  });

  test('P15-06 Android memory-first commit (theme): failed disk commit keeps last durable mode across all readers when reload returns rejected mode, then a later successful write updates all readers', () async {
    final store = _ControllablePlatformPrefsStore(const {}, true);
    store.install();
    addTearDown(store.uninstall);

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final cubit = ThemeSwitcherCubit(storage, _errorHandler());
    addTearDown(cubit.close);

    // First write succeeds -> dark is durable.
    await cubit.setThemeMode(ThemeMode.dark);
    expect(store.data['flutter.themeMode'], 'dark');
    expect(storage.themeMode, ThemeMode.dark);

    // Next write to light fails on disk while Android native memory holds light.
    store.onSet = (key, value) async => false;
    await cubit.setThemeMode(ThemeMode.light);

    expect(store.nativeMemory['flutter.themeMode'], 'light');
    expect(store.data['flutter.themeMode'], 'dark');

    final newCubitSameService = ThemeSwitcherCubit(storage, _errorHandler());
    final newCubitFreshService = ThemeSwitcherCubit(
      LocalStorageService(prefs),
      _errorHandler(),
    );
    addTearDown(newCubitSameService.close);
    addTearDown(newCubitFreshService.close);

    expect(
      cubit.state,
      const ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: true),
    );
    expect(storage.themeMode, ThemeMode.dark);
    expect(LocalStorageService(prefs).themeMode, ThemeMode.dark);
    expect(newCubitSameService.state.themeMode, ThemeMode.dark);
    expect(newCubitFreshService.state.themeMode, ThemeMode.dark);

    // A subsequent successful choice (light) becomes visible to all readers.
    store.onSet = null;
    await cubit.setThemeMode(ThemeMode.light);

    final afterSuccessCubit = ThemeSwitcherCubit(
      LocalStorageService(prefs),
      _errorHandler(),
    );
    addTearDown(afterSuccessCubit.close);

    expect(
      cubit.state,
      const ThemeSwitcherState(themeMode: ThemeMode.light, hasError: false),
    );
    expect(storage.themeMode, ThemeMode.light);
    expect(LocalStorageService(prefs).themeMode, ThemeMode.light);
    expect(afterSuccessCubit.state.themeMode, ThemeMode.light);
    expect(store.data['flutter.themeMode'], 'light');
    expect(store.nativeMemory['flutter.themeMode'], 'light');
  });
}
