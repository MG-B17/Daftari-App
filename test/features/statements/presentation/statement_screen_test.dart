import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/theme/app_color_scheme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/statements/presentation/screens/statement_screen.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(AppDateUtils.initialize);

  for (final locale in ['ar', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$locale ${mode.name} statement route renders safe mock UI', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = AppRouter.create();
        router.goNamed(
          AppRoutes.customerStatementName,
          pathParameters: {'id': 'customer-9'},
        );
        await tester.pumpWidget(
          DaftariApp(router: router, locale: Locale(locale), themeMode: mode),
        );
        await tester.pumpAndSettle();
        final screen = tester.widget<StatementScreen>(
          find.byType(StatementScreen),
        );
        expect(screen.customerId, 'customer-9');
        expect(
          router.routeInformationProvider.value.uri.path,
          '/customers/customer-9/statement',
        );
        final context = tester.element(find.byType(StatementScreen));
        final l10n = AppLocalizations.of(context)!;
        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          Theme.of(context).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(find.text(l10n.statementMockNotice), findsOneWidget);
        expect(find.text(l10n.statementSampleCustomer), findsOneWidget);
        expect(
          find.text(locale == 'ar' ? '1,250 ج.م' : '1,250 EGP'),
          findsOneWidget,
        );
        expect(find.byType(ChoiceChip), findsNWidgets(4));
        final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
        expect(chips.where((chip) => chip.selected), hasLength(1));
        expect(chips.every((chip) => chip.onSelected == null), isTrue);
        expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('statement-copy')),
        );
        await tester.pumpAndSettle();
        for (final key in ['statement-whatsapp', 'statement-copy']) {
          expect(
            tester.widget<FilledButton>(find.byKey(ValueKey(key))).onPressed,
            isNull,
          );
        }
        expect(find.text(l10n.statementFooter), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      });
    }
  }

  testWidgets('narrow RTL with large text stays scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = AppRouter.create();
    router.go('/customers/mock/statement');
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('statement-copy')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });

  test('statement semantic colors support copy and interpolation', () {
    final light = AppColorScheme.light;
    final dark = AppColorScheme.dark;
    final copy = light.copyWith(
      whatsappColor: dark.whatsappColor,
      creditSurface: dark.creditSurface,
      paymentSurface: dark.paymentSurface,
    );
    expect(copy.whatsappColor, dark.whatsappColor);
    expect(copy.creditSurface, dark.creditSurface);
    expect(copy.paymentSurface, dark.paymentSurface);
    final halfway = light.lerp(dark, .5);
    expect(
      halfway.creditSurface,
      Color.lerp(light.creditSurface, dark.creditSurface, .5),
    );
    expect(
      halfway.paymentSurface,
      Color.lerp(light.paymentSurface, dark.paymentSurface, .5),
    );
    expect(
      halfway.whatsappColor,
      Color.lerp(light.whatsappColor, dark.whatsappColor, .5),
    );
  });

  test('WhatsApp action foreground has readable contrast in both themes', () {
    for (final colors in [AppColorScheme.light, AppColorScheme.dark]) {
      final background = colors.whatsappColor.computeLuminance();
      final foreground = colors.onWhatsappColor.computeLuminance();
      expect(
        (background + .05) / (foreground + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
