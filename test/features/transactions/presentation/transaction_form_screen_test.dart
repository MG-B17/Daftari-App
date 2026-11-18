import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_amount_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_customer_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_form_body.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../customer_test_setup.dart';

void main() {
  setUp(() async => setupCustomerTests());
  tearDown(() => sl.reset());

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} $theme chooser and amount entry', (
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
        router.go('/transactions/new');
        await tester.pumpAndSettle();

        final save = find.byIcon(Icons.check_circle_outline);
        expect(save.hitTestable(), findsOneWidget);
        final savePosition = tester.getCenter(save);
        final customerCard = find.byType(TransactionCustomerCard);
        expect(
          Directionality.of(tester.element(customerCard)),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          Theme.of(tester.element(customerCard)).brightness,
          theme == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        await tester.tap(
          find.descendant(of: customerCard, matching: find.byType(TextButton)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ahmed El Shenawy').last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: customerCard,
            matching: find.text('Ahmed El Shenawy'),
          ),
          findsOneWidget,
        );

        final amountCard = find.byType(TransactionAmountCard);
        final scrollable = find
            .descendant(
              of: find.byType(TransactionFormBody),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final value in [50, 100, 200, 500]) {
          await tester.ensureVisible(find.text('+$value'));
          await tester.tap(find.text('+$value'));
          await tester.pump();
        }
        expect(tester.widget<TransactionAmountCard>(amountCard).amount, '850');
        await tester.scrollUntilVisible(
          find.byType(TransactionKeypad),
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getCenter(save), savePosition);
        final keypad = find.byType(TransactionKeypad);
        expect(
          Directionality.of(
            tester.element(
              find.descendant(of: keypad, matching: find.text('1')),
            ),
          ),
          TextDirection.ltr,
        );
        for (final key in ['.', '1', '2', '3']) {
          await tester.ensureVisible(
            find.descendant(of: keypad, matching: find.text(key)),
          );
          await tester.tap(
            find.descendant(of: keypad, matching: find.text(key)),
          );
          await tester.pump();
        }
        await tester.scrollUntilVisible(
          amountCard,
          -200,
          scrollable: scrollable,
        );
        expect(
          tester.widget<TransactionAmountCard>(amountCard).amount,
          '850.12',
        );
        await tester.scrollUntilVisible(
          find.byType(TransactionKeypad),
          200,
          scrollable: scrollable,
        );
        await tester.ensureVisible(find.byIcon(Icons.backspace_outlined));
        await tester.tap(find.byIcon(Icons.backspace_outlined));
        await tester.pump();
        await tester.scrollUntilVisible(
          amountCard,
          -200,
          scrollable: scrollable,
        );
        expect(
          tester.widget<TransactionAmountCard>(amountCard).amount,
          '850.1',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        router.dispose();
      });
    }
  }
}
