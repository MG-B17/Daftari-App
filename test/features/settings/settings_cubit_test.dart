import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
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
}
