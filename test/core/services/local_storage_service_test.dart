import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults and persistence of typed preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = LocalStorageService(preferences);
    expect(service.localeCode, 'ar');
    expect(service.themeMode, ThemeMode.system);
    expect(service.onboardingCompleted, isFalse);
    await service.setLocaleCode('en');
    await service.setThemeMode(ThemeMode.dark);
    await service.setOnboardingCompleted(true);
    await preferences.reload();
    final restored = LocalStorageService(preferences);
    expect(restored.localeCode, 'en');
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.onboardingCompleted, isTrue);
    await service.setLocaleCode('ar');
    for (final mode in ThemeMode.values) {
      await service.setThemeMode(mode);
      expect(service.themeMode, mode);
    }
    await service.setOnboardingCompleted(false);
    expect(service.localeCode, 'ar');
    expect(service.onboardingCompleted, isFalse);
  });

  test('corrupt preference values fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'localeCode': 123,
      'themeMode': 'unknown',
      'onboardingCompleted': 'true',
    });
    final service = LocalStorageService(await SharedPreferences.getInstance());
    expect(service.localeCode, 'ar');
    expect(service.themeMode, ThemeMode.system);
    expect(service.onboardingCompleted, isFalse);
    await expectLater(
      service.setLocaleCode('private invalid value'),
      throwsA(isA<ValidationException>()),
    );
    expect(service.localeCode, 'ar');
  });

  test(
    'failed writes, thrown plugin errors, and reads are sanitized',
    () async {
      final preferences = MockPreferences();
      final service = LocalStorageService(preferences);
      when(() => preferences.setString('localeCode', 'en'))
          .thenAnswer((_) async => false);
      await expectLater(
        service.setLocaleCode('en'),
        throwsA(isA<StorageException>()),
      );
      when(() => preferences.setBool('onboardingCompleted', true))
          .thenThrow(Exception('private data'));
      await expectLater(
        service.setOnboardingCompleted(true),
        throwsA(isA<StorageException>()),
      );
      when(() => preferences.get('localeCode'))
          .thenThrow(Exception('private data'));
      expect(() => service.localeCode, throwsA(isA<StorageException>()));
    },
  );
}
