import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/features/layout/presentation/widgets/liquid_navigation_bar.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftariapp/core/di/service_locator.dart';

import '../../customer_test_setup.dart';

void main() {
  setUp(() async => setupCustomerTests());
  tearDown(() => sl.reset());
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
          final errorHandler = ErrorHandler(
            AppLogger(output: (_) {}, enableCrashReporting: false),
          );
          final cubit = SettingsCubit(
            GetSettingsUseCase(repository),
            ChangeLanguageUseCase(repository),
            errorHandler,
          );
          final themeSwitcher = ThemeSwitcherCubit(storage, errorHandler);
          final router = AppRouter.create();
          await tester.pumpWidget(
            DaftariApp(
              router: router,
              settingsCubit: cubit,
              themeSwitcherCubit: themeSwitcher,
              appLockCubit: sl<AppLockCubit>(),
            ),
          );
          await tester.pumpAndSettle();
          // Set the desired test settings through the production Cubits.
          await cubit.setLocaleCode(locale.languageCode);
          await themeSwitcher.setThemeMode(mode);
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.home), findsOneWidget);
          expect(find.byIcon(Icons.people_outline), findsWidgets);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('navigation-1')),
              matching: find.byType(Text),
            ),
            findsNothing,
          );
          final indicator = find.byKey(const ValueKey('navigation-indicator'));
          final start = tester.getCenter(indicator).dx;
          await tester.tap(find.byKey(const ValueKey('navigation-1')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final middle = tester.getCenter(indicator).dx;
          await tester.pumpAndSettle();
          final end = tester.getCenter(indicator).dx;
          expect(
            middle,
            inExclusiveRange(
              start < end ? start : end,
              start < end ? end : start,
            ),
          );
          expect(
            (end -
                    tester
                        .getCenter(find.byKey(const ValueKey('navigation-1')))
                        .dx)
                .abs(),
            lessThan(1),
          );
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutes.customers,
          );
          expect(find.byIcon(Icons.people), findsOneWidget);
          final fab = tester.getRect(find.byType(FloatingActionButton));
          final nav = tester.getRect(
            find.byKey(const ValueKey('navigation-1')),
          );
          expect(fab.bottom, lessThan(nav.top));
          await tester.ensureVisible(
            find.byKey(const ValueKey('customers-filter-settled')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('customers-filter-settled')),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(
                  find.byKey(const ValueKey('customers-filter-settled')),
                )
                .selected,
            isTrue,
          );
          await tester.tap(find.byKey(const ValueKey('navigation-2')));
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRoutes.settings,
          );
          expect(find.byIcon(Icons.settings), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('navigation-1')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(
                  find.byKey(const ValueKey('customers-filter-settled')),
                )
                .selected,
            isTrue,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          router.dispose();
          await cubit.close();
          await themeSwitcher.close();
        },
      );
    }
  }

  testWidgets('reduced motion snaps indicator and exposes selected semantics', (
    tester,
  ) async {
    var selected = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) => LiquidNavigationBar(
                  items: const [
                    LiquidNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Home',
                    ),
                    LiquidNavItem(
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      label: 'Customers',
                    ),
                    LiquidNavItem(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: 'Settings',
                    ),
                  ],
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-2')));
    await tester.pump();
    expect(
      tester.getCenter(find.byKey(const ValueKey('navigation-indicator'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('navigation-2'))).dx,
        1,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('navigation-2'))),
      matchesSemantics(
        label: 'Settings',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isFocusable: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('generic items work without Daftari theme extensions', (
    tester,
  ) async {
    Widget app(List<LiquidNavItem> items, int index) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidNavigationBar(
            items: items,
            selectedIndex: index,
            onSelected: (_) {},
            indicatorColor: Colors.purple,
          ),
        ),
      ),
    );
    const items = [
      LiquidNavItem(
        icon: Icons.star_border,
        selectedIcon: Icons.star,
        label: 'Star',
      ),
      LiquidNavItem(
        icon: Icons.book_outlined,
        selectedIcon: Icons.book,
        label: 'Books',
      ),
    ];
    await tester.pumpWidget(app(items.sublist(0, 1), 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('navigation-indicator')),
    );
    expect((box.decoration as BoxDecoration).color, Colors.purple);
    await tester.pumpWidget(app(items, 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('navigation-indicator'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('navigation-1'))).dx,
        1,
      ),
    );
  });
}
