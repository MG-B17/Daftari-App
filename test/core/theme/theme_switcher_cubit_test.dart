import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/core/theme/theme_switcher_cubit.dart';
import 'package:daftariapp/core/theme/theme_switcher_state.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStorage extends Mock implements LocalStorageService {}

class _MockErrorHandler extends Mock implements ErrorHandler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStorage storage;
  late _MockErrorHandler handler;

  setUpAll(() {
    registerFallbackValue(ThemeMode.system);
  });

  setUp(() {
    storage = _MockStorage();
    handler = _MockErrorHandler();
    when(() => storage.themeMode).thenReturn(ThemeMode.system);
    when(() => storage.setThemeMode(any())).thenAnswer((_) async {});
    when(() => handler.handle(any()))
        .thenAnswer((_) async => const AppFailure(AppErrorCode.storage));
  });

  test('state exposes defaults, copyWith and value equality', () {
    const state = ThemeSwitcherState(themeMode: ThemeMode.dark);
    expect(const ThemeSwitcherState().themeMode, ThemeMode.system);
    expect(const ThemeSwitcherState().hasError, isFalse);
    expect(state.copyWith(), state);
    expect(
      state.copyWith(themeMode: ThemeMode.light),
      const ThemeSwitcherState(themeMode: ThemeMode.light),
    );
    expect(
      state.copyWith(hasError: true),
      const ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: true),
    );
  });

  for (final mode in ThemeMode.values) {
    test(
      'retains saved ${mode.name} preference from existing themeMode key',
      () async {
        SharedPreferences.setMockInitialValues({'themeMode': mode.name});
        final prefs = await SharedPreferences.getInstance();
        final localStorage = LocalStorageService(prefs);
        final cubit = ThemeSwitcherCubit(localStorage, handler);
        expect(cubit.state, ThemeSwitcherState(themeMode: mode));
        await cubit.close();
      },
    );
  }

  test('missing preference defaults to system mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = ThemeSwitcherCubit(LocalStorageService(prefs), handler);
    expect(cubit.state, const ThemeSwitcherState(themeMode: ThemeMode.system));
    await cubit.close();
  });

  for (final invalid in <Object>['unknown', '', 'DARK', 123, true]) {
    test('invalid preference ($invalid) falls back to system mode', () async {
      SharedPreferences.setMockInitialValues({'themeMode': invalid});
      final prefs = await SharedPreferences.getInstance();
      final cubit = ThemeSwitcherCubit(LocalStorageService(prefs), handler);
      expect(
        cubit.state,
        const ThemeSwitcherState(themeMode: ThemeMode.system),
      );
      await cubit.close();
    });
  }

  test('falls back to system mode when reading storage throws', () async {
    when(() => storage.themeMode).thenThrow(const StorageException());
    final cubit = ThemeSwitcherCubit(storage, handler);
    expect(cubit.state, const ThemeSwitcherState(themeMode: ThemeMode.system));
    await cubit.close();
  });

  blocTest<ThemeSwitcherCubit, ThemeSwitcherState>(
    'selecting light, dark and system emits immediately and persists',
    build: () => ThemeSwitcherCubit(storage, handler),
    act: (cubit) async {
      await cubit.setThemeMode(ThemeMode.light);
      await cubit.setThemeMode(ThemeMode.dark);
      await cubit.setThemeMode(ThemeMode.system);
    },
    expect: () => const [
      ThemeSwitcherState(themeMode: ThemeMode.light),
      ThemeSwitcherState(themeMode: ThemeMode.dark),
      ThemeSwitcherState(themeMode: ThemeMode.system),
    ],
    verify: (_) {
      verify(() => storage.setThemeMode(ThemeMode.light)).called(1);
      verify(() => storage.setThemeMode(ThemeMode.dark)).called(1);
      verify(() => storage.setThemeMode(ThemeMode.system)).called(1);
    },
  );

  blocTest<ThemeSwitcherCubit, ThemeSwitcherState>(
    're-selecting the current mode does not write again',
    build: () => ThemeSwitcherCubit(storage, handler),
    act: (cubit) => cubit.setThemeMode(ThemeMode.system),
    expect: () => const <ThemeSwitcherState>[],
    verify: (_) => verifyNever(() => storage.setThemeMode(any())),
  );

  test('persisted selection survives restart under themeMode key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ThemeSwitcherCubit(LocalStorageService(prefs), handler);
    await first.setThemeMode(ThemeMode.dark);
    await first.close();

    await prefs.reload();
    expect(prefs.getString('themeMode'), 'dark');
    final restarted = ThemeSwitcherCubit(LocalStorageService(prefs), handler);
    expect(
      restarted.state,
      const ThemeSwitcherState(themeMode: ThemeMode.dark),
    );
    await restarted.close();
  });

  blocTest<ThemeSwitcherCubit, ThemeSwitcherState>(
    'save failure reverts to previous mode and reports error',
    build: () {
      when(() => storage.themeMode).thenReturn(ThemeMode.light);
      when(() => storage.setThemeMode(ThemeMode.dark))
          .thenThrow(const StorageException());
      return ThemeSwitcherCubit(storage, handler);
    },
    act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
    expect: () => const [
      ThemeSwitcherState(themeMode: ThemeMode.dark),
      ThemeSwitcherState(themeMode: ThemeMode.light, hasError: true),
    ],
    verify: (_) => verify(() => handler.handle(any())).called(1),
  );

  blocTest<ThemeSwitcherCubit, ThemeSwitcherState>(
    'repeated save failure clears and re-emits hasError',
    build: () {
      when(() => storage.themeMode).thenReturn(ThemeMode.light);
      when(() => storage.setThemeMode(ThemeMode.dark))
          .thenThrow(const StorageException());
      return ThemeSwitcherCubit(storage, handler);
    },
    act: (cubit) async {
      await cubit.setThemeMode(ThemeMode.dark);
      await cubit.setThemeMode(ThemeMode.dark);
    },
    expect: () => const [
      ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: false),
      ThemeSwitcherState(themeMode: ThemeMode.light, hasError: true),
      ThemeSwitcherState(themeMode: ThemeMode.dark, hasError: false),
      ThemeSwitcherState(themeMode: ThemeMode.light, hasError: true),
    ],
    verify: (_) => verify(() => handler.handle(any())).called(2),
  );

  test(
    'stale save failure does not overwrite a newer successful selection',
    () async {
      final firstWrite = Completer<void>();
      when(() => storage.themeMode).thenReturn(ThemeMode.light);
      when(() => storage.setThemeMode(ThemeMode.dark))
          .thenAnswer((_) => firstWrite.future);
      when(() => storage.setThemeMode(ThemeMode.system))
          .thenAnswer((_) async {});

      final cubit = ThemeSwitcherCubit(storage, handler);
      final firstCall = cubit.setThemeMode(ThemeMode.dark);
      await cubit.setThemeMode(ThemeMode.system);
      expect(
        cubit.state,
        const ThemeSwitcherState(themeMode: ThemeMode.system),
      );

      firstWrite.completeError(const StorageException());
      await firstCall;

      expect(
        cubit.state,
        const ThemeSwitcherState(themeMode: ThemeMode.system, hasError: false),
      );
      verify(() => handler.handle(any())).called(1);
      await cubit.close();
    },
  );
}
