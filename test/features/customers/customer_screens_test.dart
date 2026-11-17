import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/features/customers/presentation/customer_mock_data.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customer_details_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} $theme form and details', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = AppRouter.create();
        await tester.pumpWidget(
          DaftariApp(router: router, locale: locale, themeMode: theme),
        );
        await tester.pumpAndSettle();
        router.go('/customers/new');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('customer-name')), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-phone')), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-notes')), findsOneWidget);
        router.go('/customers/2');
        await tester.pumpAndSettle();
        expect(find.text('01124567890'), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-call')), findsOneWidget);
        router.go('/customers/2/edit');
        await tester.pumpAndSettle();
        expect(find.text('01124567890'), findsOneWidget);
        router.go('/customers/missing');
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'ar'
                ? 'العميل غير موجود'
                : 'Customer not found',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      });
    }
  }

  testWidgets('call opens tel URI and reports failure', (tester) async {
    Uri? received;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: CustomerDetailsBody(
              customer: const CustomerMock('1', 'Test', '01012345678', 0),
              launchPhone: (uri) async {
                received = uri;
                return false;
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-call')));
    await tester.pumpAndSettle();
    expect(received.toString(), 'tel:01012345678');
    expect(find.text('Could not open the phone app.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
