import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/theme/colors/app_colors.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/widgets/app_button.dart';
import 'package:daftariapp/core/widgets/app_confirmation_dialog.dart';
import 'package:daftariapp/core/widgets/app_empty_state.dart';
import 'package:daftariapp/core/widgets/app_error_state.dart';
import 'package:daftariapp/core/widgets/app_loading_indicator.dart';
import 'package:daftariapp/core/widgets/app_scaffold.dart';
import 'package:daftariapp/core/widgets/app_text_field.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_test_setup.dart';

Future<void> pumpShared(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: AppConstants.designSize,
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        locale: locale,
        supportedLocales: AppConstants.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: AppScaffold(body: child),
      ),
    ),
  );
  // ScreenUtil and localization delegates can schedule additional frames.
  await tester.pump();
}

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  for (final locale in AppConstants.supportedLocales) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} ${mode.name} app foundation', (
        tester,
      ) async {
        await tester.pumpWidget(DaftariApp(locale: locale, themeMode: mode));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(DashboardScreen));
        expect(
          Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        final theme = Theme.of(context);
        expect(
          theme.brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(theme.useMaterial3, isTrue);
        expect(theme.textTheme.bodyMedium!.fontFamily, 'Cairo');
        expect(
          theme.scaffoldBackgroundColor,
          mode == ThemeMode.dark
              ? AppColors.darkBackground
              : AppColors.background,
        );
        expect(
          theme.colorScheme.primary,
          mode == ThemeMode.dark ? AppColors.mint : AppColors.primary,
        );
        expect(
          find.text(
            locale.languageCode == 'ar' ? 'دفتر الحسابات' : 'Account ledger',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'default locale is Arabic and injected router remains caller-owned',
    (tester) async {
      final router = AppRouter.create();
      await tester.pumpWidget(DaftariApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('دفتر الحسابات'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      // The caller can still use and dispose its router after app unmount.
      expect(router.routeInformationProvider.value.uri.path, '/');
      router.dispose();
    },
  );

  test('dependency configuration is idempotent', () async {
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
    await configureDependencies();
    final router = sl<GoRouter>();
    await configureDependencies();
    expect(sl<GoRouter>(), same(router));
    await sl.reset();
  });

  for (final variant in AppButtonVariant.values) {
    testWidgets('${variant.name} button supports tap, icon, and full width', (
      tester,
    ) async {
      var taps = 0;
      await pumpShared(
        tester,
        AppButton(
          label: 'Save',
          onPressed: () => taps++,
          variant: variant,
          icon: Icons.save,
          fullWidth: true,
        ),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(taps, 1);
      final buttonWidth = tester.getSize(find.byType(AppButton)).width;
      final bodyWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(buttonWidth, lessThan(bodyWidth));
      expect(buttonWidth, greaterThan(bodyWidth / 2));
    });
  }

  testWidgets('loading and disabled buttons cannot be tapped', (tester) async {
    var taps = 0;
    await pumpShared(
      tester,
      AppButton(label: 'Save', onPressed: () => taps++, isLoading: true),
    );
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    await pumpShared(
      tester,
      const AppButton(label: 'Disabled', onPressed: null),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('text field label, required hint, affixes, input, validation', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpShared(
      tester,
      Form(
        key: key,
        child: AppTextField(
          label: 'Name',
          controller: controller,
          isRequired: true,
          prefix: const Icon(Icons.person),
          suffix: const Icon(Icons.check),
          validator: (value) =>
              value == null || value.isEmpty ? 'Enter a name' : null,
        ),
      ),
    );
    expect(find.text('Name *', findRichText: true), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Ali');
    expect(controller.text, 'Ali');
    expect(key.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Enter a name'), findsNothing);
  });

  testWidgets('optional field supports external error text', (tester) async {
    await pumpShared(
      tester,
      const AppTextField(label: 'Phone', errorText: 'Invalid'),
    );
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Invalid'), findsOneWidget);
    expect(find.text('*'), findsNothing);
  });

  testWidgets('empty and error defaults localize in Arabic and retry works', (
    tester,
  ) async {
    await pumpShared(tester, const AppEmptyState(), locale: const Locale('ar'));
    expect(find.text('لا توجد بيانات بعد'), findsOneWidget);
    var retries = 0;
    await pumpShared(
      tester,
      AppErrorState(onRetry: () => retries++),
      locale: const Locale('ar'),
      mode: ThemeMode.dark,
    );
    expect(find.text('حدث خطأ'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
    await pumpShared(tester, const AppErrorState());
    expect(find.text('Retry'), findsNothing);
  });

  for (final confirm in [true, false]) {
    testWidgets('confirmation dialog returns $confirm', (tester) async {
      bool? result;
      await pumpShared(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'Open',
            onPressed: () async {
              result = await AppConfirmationDialog.show(
                context,
                title: 'Delete?',
                message: 'This cannot be undone.',
                isDestructive: true,
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      await tester.tap(find.text(confirm ? 'Confirm' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, confirm);
      expect(find.byType(AppConfirmationDialog), findsNothing);
    });
  }

  testWidgets('dialog barrier dismissal returns false', (tester) async {
    bool? result;
    await pumpShared(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'Open',
          onPressed: () async {
            result = await AppConfirmationDialog.show(
              context,
              title: 'Confirm?',
              message: 'Continue?',
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('shared controls fit a narrow RTL screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpShared(
      tester,
      ListView(
        children: [
          const AppTextField(label: 'اسم العميل', isRequired: true),
          AppButton(
            label: 'حفظ العميل في الدفتر',
            icon: Icons.save,
            fullWidth: true,
            onPressed: () {},
          ),
          const AppEmptyState(),
        ],
      ),
      locale: const Locale('ar'),
    );
    expect(
      Directionality.of(tester.element(find.byType(AppTextField))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
