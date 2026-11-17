import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${locale.languageCode} $mode switches and preserves branch state',
        (tester) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final storage = LocalStorageService(
            await SharedPreferences.getInstance(),
          );
          final repository = SettingsRepositoryImpl(storage);
          final cubit = SettingsCubit(
            GetSettingsUseCase(repository),
            ChangeLanguageUseCase(repository),
            ChangeThemeUseCase(repository),
            ErrorHandler(
              AppLogger(output: (_) {}, enableCrashReporting: false),
            ),
          );
          final router = AppRouter.create();
          await tester.pumpWidget(
            DaftariApp(router: router, settingsCubit: cubit),
          );
          await tester.pumpAndSettle();
          // Set the desired test settings through the production Cubit.
          await cubit.setLocaleCode(locale.languageCode);
          await cubit.setThemeMode(mode);
          await tester.pumpAndSettle();
          var bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.selectedIndex, 0);
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(Icons.people_outline),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutes.customers,
          );
          bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.selectedIndex, 1);
          await tester.enterText(
            find.byKey(const ValueKey('customers-search')),
            '010123',
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(Icons.settings_outlined),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutes.settings,
          );
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            2,
          );
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(Icons.people_outline),
            ),
          );
          await tester.pumpAndSettle();
          final field = find.descendant(
            of: find.byKey(const ValueKey('customers-search')),
            matching: find.byType(EditableText),
          );
          expect(tester.widget<EditableText>(field).controller.text, '010123');
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          await cubit.close();
        },
      );
    }
  }
}
