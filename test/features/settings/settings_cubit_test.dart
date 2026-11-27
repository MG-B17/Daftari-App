import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_state.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Mock implements LocalStorageService {}

class _Handler extends Mock implements ErrorHandler {}

void main() {
  late _Storage storage;
  late _Handler handler;

  setUp(() {
    storage = _Storage();
    handler = _Handler();
    when(() => storage.localeCode).thenReturn('ar');
    when(() => storage.setLocaleCode(any())).thenAnswer((_) async {});
    when(() => handler.handle(any()))
        .thenAnswer((_) async => const AppFailure(AppErrorCode.storage));
  });

  test('reads the persisted locale on creation', () async {
    when(() => storage.localeCode).thenReturn('en');
    final cubit = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      handler,
    );
    expect(cubit.state, const SettingsState(localeCode: 'en'));
    expect(cubit.state.locale, const Locale('en'));
    expect(cubit.state.isArabic, isFalse);
    await cubit.close();
  });

  test(
    'falls back to defaults when the stored values cannot be read',
    () async {
      when(() => storage.localeCode).thenThrow(const StorageException());
      final cubit = SettingsCubit(
        GetSettingsUseCase(SettingsRepositoryImpl(storage)),
        ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
        handler,
      );
      expect(cubit.state, const SettingsState());
      expect(cubit.state.locale, const Locale('ar'));
      await cubit.close();
    },
  );

  test('state exposes Arabic natively and value equality', () {
    const state = SettingsState(localeCode: 'en');
    expect(state.isArabic, isFalse);
    expect(state.locale.languageCode, 'en');
    expect(state.copyWith(), state);
    expect(state.copyWith(localeCode: 'ar').isArabic, isTrue);
    expect(state.copyWith(hasError: true).hasError, isTrue);
    expect(const SettingsState().isArabic, isTrue);
  });

  blocTest<SettingsCubit, SettingsState>(
    'locale change emits immediately and persists',
    build: () => SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      handler,
    ),
    act: (cubit) => cubit.setLocaleCode('en'),
    expect: () => [const SettingsState(localeCode: 'en')],
    verify: (_) => verify(() => storage.setLocaleCode('en')).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'selecting the current values does not write again',
    build: () => SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      handler,
    ),
    act: (cubit) => cubit.setLocaleCode('ar'),
    expect: () => const <SettingsState>[],
    verify: (_) => verifyNever(() => storage.setLocaleCode(any())),
  );

  blocTest<SettingsCubit, SettingsState>(
    'locale failure reverts and reports the error',
    build: () {
      when(() => storage.setLocaleCode('en'))
          .thenThrow(const StorageException());
      return SettingsCubit(
        GetSettingsUseCase(SettingsRepositoryImpl(storage)),
        ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
        handler,
      );
    },
    act: (cubit) => cubit.setLocaleCode('en'),
    expect: () => [
      const SettingsState(localeCode: 'en'),
      const SettingsState(hasError: true),
    ],
    verify: (_) => verify(() => handler.handle(any())).called(1),
  );

  blocTest<SettingsCubit, SettingsState>(
    'repeated locale failure clears and re-emits hasError',
    build: () {
      when(() => storage.setLocaleCode('en'))
          .thenThrow(const StorageException());
      return SettingsCubit(
        GetSettingsUseCase(SettingsRepositoryImpl(storage)),
        ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
        handler,
      );
    },
    act: (cubit) async {
      await cubit.setLocaleCode('en');
      await cubit.setLocaleCode('en');
    },
    expect: () => const [
      SettingsState(localeCode: 'en', hasError: false),
      SettingsState(localeCode: 'ar', hasError: true),
      SettingsState(localeCode: 'en', hasError: false),
      SettingsState(localeCode: 'ar', hasError: true),
    ],
    verify: (_) => verify(() => handler.handle(any())).called(2),
  );

  test(
    'stale locale failure does not overwrite a newer successful selection',
    () async {
      final firstWrite = Completer<void>();
      when(() => storage.setLocaleCode('en'))
          .thenAnswer((_) => firstWrite.future);
      when(() => storage.setLocaleCode('ar')).thenAnswer((_) async {});

      final cubit = SettingsCubit(
        GetSettingsUseCase(SettingsRepositoryImpl(storage)),
        ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
        handler,
      );
      final firstCall = cubit.setLocaleCode('en');
      await cubit.setLocaleCode('ar');
      expect(cubit.state, const SettingsState(localeCode: 'ar'));

      firstWrite.completeError(const StorageException());
      await firstCall;

      expect(
        cubit.state,
        const SettingsState(localeCode: 'ar', hasError: false),
      );
      verify(() => handler.handle(any())).called(1);
      await cubit.close();
    },
  );

  test('P15-06: overlapping language writes preserve earlier persisted locale when later write fails', () async {
    var persistedLocale = 'ar';
    final enWrite = Completer<void>();
    final arWrite = Completer<void>();

    when(() => storage.localeCode).thenAnswer((_) => persistedLocale);
    when(() => storage.setLocaleCode('en')).thenAnswer((_) async {
      await enWrite.future;
      persistedLocale = 'en';
    });
    when(() => storage.setLocaleCode('ar')).thenAnswer((_) async {
      await arWrite.future;
      persistedLocale = 'ar';
    });

    final repo = SettingsRepositoryImpl(storage);
    final cubit = SettingsCubit(
      GetSettingsUseCase(repo),
      ChangeLanguageUseCase(repo),
      handler,
    );
    expect(cubit.state.localeCode, 'ar');

    final enCall = cubit.setLocaleCode('en');
    expect(cubit.state, const SettingsState(localeCode: 'en'));

    final arCall = cubit.setLocaleCode('ar');
    expect(cubit.state, const SettingsState(localeCode: 'ar'));

    enWrite.complete();
    await enCall;
    expect(cubit.state, const SettingsState(localeCode: 'ar'));

    arWrite.completeError(const StorageException());
    await arCall;

    final reloaded = SettingsCubit(
      GetSettingsUseCase(repo),
      ChangeLanguageUseCase(repo),
      handler,
    );
    expect(reloaded.state.localeCode, 'en');
    expect(cubit.state, const SettingsState(localeCode: 'en', hasError: true));
    expect(cubit.state.localeCode, reloaded.state.localeCode);
    verify(() => handler.handle(any())).called(1);
    await reloaded.close();
    await cubit.close();
  });
}
