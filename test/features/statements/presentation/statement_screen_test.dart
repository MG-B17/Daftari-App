import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/core/theme/app_color_scheme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/statements/data/repositories/statement_repository_impl.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/statements/domain/formatters/statement_formatter.dart';
import 'package:daftariapp/features/statements/domain/repositories/statement_repository.dart';
import 'package:daftariapp/features/statements/domain/usecases/get_customer_statement_usecase.dart';
import 'package:daftariapp/features/statements/presentation/cubit/statement_cubit.dart';
import 'package:daftariapp/features/statements/presentation/screens/statement_screen.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/statement_fixtures.dart';
import '../statement_image_fakes.dart';

typedef _Result = Either<AppFailure, CustomerStatementEntity?>;

class _Repository implements StatementRepository {
  final ranges = <StatementDateRange>[];
  Future<_Result> Function(StatementDateRange)? handler;

  @override
  Future<_Result> getCustomerStatement(
    String customerId, {
    StatementDateRange range = StatementDateRange.all,
  }) {
    ranges.add(range);
    return handler?.call(range) ??
        Future.value(
          Right(
            statementFixture(
              entries: [statementTransaction(note: 'Live credit')],
              range: range,
            ),
          ),
        );
  }
}

class _Dates implements DateService {
  @override
  DateTime now() => statementNow;
}

void main() {
  late _Repository repository;
  late StatementRepository source;
  late List<Uri> launches;
  late List<ShareParams> shares;
  late List<String> logs;
  late FakeStatementImageRenderer renderer;
  late bool shareThrows;
  late bool clipboardThrows;
  late ShareResultStatus shareStatus;
  Completer<ShareResult>? pendingShare;
  String? copied;
  late StatementCubit cubit;
  final errors = ErrorHandler(AppLogger(output: (_) {}));

  setUpAll(AppDateUtils.initialize);
  setUp(() {
    repository = _Repository();
    source = repository;
    launches = [];
    shares = [];
    logs = [];
    renderer = FakeStatementImageRenderer();
    shareThrows = false;
    clipboardThrows = false;
    shareStatus = ShareResultStatus.success;
    pendingShare = null;
    copied = null;
    sl.registerFactory<StatementCubit>(() {
      cubit = StatementCubit(
        GetCustomerStatementUseCase(source),
        MemoryStatementShareService(
          ErrorHandler(AppLogger(output: logs.add)),
          handler: (params) async {
            shares.add(params);
            if (shareThrows) throw StateError('Private platform error');
            return pendingShare?.future ?? ShareResult('', shareStatus);
          },
        ),
        renderer,
      );
      return cubit;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardThrows) throw PlatformException(code: 'clipboard');
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await sl.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    ThemeMode mode = ThemeMode.light,
    String id = 'c1',
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    addTearDown(router.dispose);
    router.goNamed(AppRoutes.customerStatementName, pathParameters: {'id': id});
    await tester.pumpWidget(
      DaftariApp(router: router, locale: Locale(locale), themeMode: mode),
    );
    if (settle) await tester.pumpAndSettle();
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(StatementScreen)))!;

  Future<void> tapAction(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    if (cubit.state.sharing) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
    await tester.tap(finder);
    await tester.pump();
    if (!cubit.state.sharing) await tester.pumpAndSettle();
  }

  for (final locale in ['ar', 'en']) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$locale ${mode.name} renders and copies live offline data', (
        tester,
      ) async {
        await pump(tester, locale: locale, mode: mode);
        final context = tester.element(find.byType(StatementScreen));
        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          Theme.of(context).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(find.text('Test Customer'), findsOneWidget);
        expect(find.text('Live credit'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('statement-mock-notice')),
          findsNothing,
        );
        expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
        expect(find.byType(ChoiceChip), findsNWidgets(4));
        expect(launches, isEmpty);
        expect(shares, isEmpty);
        expect(copied, isNull);
        await tapAction(tester, 'statement-copy');
        expect(
          copied,
          StatementFormatter.format(cubit.state.statement!, locale: locale),
        );
        expect(find.text(l10n(tester).statementCopied), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubit.isClosed, isTrue);
      });
    }
  }

  testWidgets('range chips reload; custom picker cancellation keeps range', (
    tester,
  ) async {
    await pump(tester);
    await tapAction(tester, 'statement-range-1');
    expect(cubit.state.range, StatementDateRange.last30Days);
    await tapAction(tester, 'statement-range-2');
    expect(cubit.state.range, StatementDateRange.thisMonth);
    await tapAction(tester, 'statement-range-3');
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    final pickerContext = tester.element(find.byType(DateRangePickerDialog));
    Navigator.of(pickerContext).pop();
    await tester.pumpAndSettle();
    expect(cubit.state.range, StatementDateRange.thisMonth);
    await tapAction(tester, 'statement-range-3');
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 3)),
    );
    await tester.pumpAndSettle();
    expect(
      cubit.state.range,
      StatementDateRange.custom(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 3),
      ),
    );
    await tapAction(tester, 'statement-range-0');
    expect(cubit.state.range, StatementDateRange.all);
  });

  testWidgets(
    'loading uses shared screen loader; error retries; missing customer cannot share',
    (tester) async {
      final pending = Completer<_Result>();
      repository.handler = (_) => pending.future;
      await pump(tester, settle: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final loader = tester.widget<DaftariLoading>(find.byType(DaftariLoading));
      expect(loader.variant, DaftariLoadingVariant.screen);
      expect(find.byKey(const ValueKey('statement-whatsapp')), findsNothing);
      pending.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).statementLoadError), findsOneWidget);
      repository.handler = (_) async => const Right(null);
      await tester.tap(find.text(l10n(tester).retry));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).customerNotFound), findsOneWidget);
      expect(find.byKey(const ValueKey('statement-copy')), findsNothing);
      expect(shares, isEmpty);
    },
  );

  testWidgets('empty history is valid, copyable and settled', (tester) async {
    repository.handler = (_) async => Right(statementFixture());
    await pump(tester);
    expect(find.text(l10n(tester).statementEmpty), findsOneWidget);
    expect(find.text(l10n(tester).statementSettledHint), findsOneWidget);
    await tapAction(tester, 'statement-copy');
    expect(copied, contains('No transactions in this period.'));
  });

  testWidgets(
    'overpayment shows customer credit instead of a payment request',
    (tester) async {
      repository.handler = (_) async => Right(
        statementFixture(
          entries: [
            statementTransaction(type: TransactionType.payment, amount: 500),
          ],
        ),
      );
      await pump(tester);
      expect(
        find.text(l10n(tester).statementCreditBalanceHint),
        findsOneWidget,
      );
      expect(find.text(l10n(tester).statementBalanceHint), findsNothing);
    },
  );

  testWidgets(
    'primary action shares PNG files, confirms handoff without claiming delivery, and stays on screen',
    (tester) async {
      await pump(tester);
      await tapAction(tester, 'statement-whatsapp');
      expect(launches, isEmpty);
      expect(shares.single.text, isNull);
      expect(shares.single.files!.single.mimeType, 'image/png');
      expect(shares.single.sharePositionOrigin!.isEmpty, isFalse);
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(
        find.text(l10n(tester).statementShareHandedOffTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n(tester).statementShareHandedOffMessage),
        findsOneWidget,
      );
      expect(find.byType(AppErrorDialog), findsNothing);
      expect(logs, isEmpty);

      await tester.tap(find.text(l10n(tester).ok));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(StatementScreen), findsOneWidget);
    },
  );

  testWidgets(
    'generation and handoff stages use inline shared loader, block duplicate taps, and distinguish cancellation',
    (tester) async {
      renderer.pendingRender = Completer<void>();
      pendingShare = Completer<ShareResult>();
      await pump(tester);
      final preview = tester.widget(
        find.byKey(const ValueKey('statement-balance')),
      );

      await tapAction(tester, 'statement-whatsapp');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('statement-whatsapp')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<DaftariLoading>(find.byType(DaftariLoading)).variant,
        DaftariLoadingVariant.inline,
      );
      expect(find.text(l10n(tester).statementGenerating), findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey('statement-balance'))),
        same(preview),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('statement-copy')))
            .onPressed,
        isNotNull,
      );

      renderer.pendingRender!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n(tester).statementHandingOff), findsOneWidget);
      expect(
        tester.widget<DaftariLoading>(find.byType(DaftariLoading)).variant,
        DaftariLoadingVariant.inline,
      );

      pendingShare!.complete(
        const ShareResult('', ShareResultStatus.dismissed),
      );
      await tester.pumpAndSettle();
      expect(shares, hasLength(1));
      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.text(l10n(tester).statementShareCancelled), findsOneWidget);
    },
  );

  testWidgets(
    'unavailable share sheet status reports handoff without showing success or error dialog',
    (tester) async {
      shareStatus = ShareResultStatus.unavailable;
      await pump(tester);
      await tapAction(tester, 'statement-whatsapp');
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.text(l10n(tester).statementShareSheetOpened), findsOneWidget);
    },
  );

  testWidgets(
    'generation failure displays dedicated error dialog and retains snapshot for retry',
    (tester) async {
      renderer.throwsError = true;
      await pump(tester);
      await tapAction(tester, 'statement-whatsapp');
      expect(find.byType(AppErrorDialog), findsOneWidget);
      expect(find.text(l10n(tester).statementGenerateError), findsOneWidget);
      expect(shares, isEmpty);

      await tester.tap(find.text(l10n(tester).ok));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsNothing);

      renderer.throwsError = false;
      await tapAction(tester, 'statement-whatsapp');
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(shares, hasLength(1));
    },
  );

  testWidgets(
    'share handoff and clipboard errors display safe localized feedback',
    (tester) async {
      shareThrows = true;
      clipboardThrows = true;
      await pump(tester);
      await tapAction(tester, 'statement-whatsapp');
      expect(find.byType(AppErrorDialog), findsOneWidget);
      expect(find.text(l10n(tester).statementShareError), findsOneWidget);
      await tester.tap(find.text(l10n(tester).ok));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsNothing);

      await tapAction(tester, 'statement-copy');
      expect(find.text(l10n(tester).statementCopyError), findsOneWidget);
      expect(copied, isNull);
      expect(logs.join(), isNot(contains('Private platform error')));
    },
  );

  testWidgets(
    'real Drift snapshot excludes deleted transactions from preview and copy',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      late String id;
      await tester.runAsync(() async {
        final customer = await db.customerDao.createCustomer(
          name: 'Offline customer',
        );
        id = customer.id;
        await db.transactionDao.createTransaction(
          customerId: id,
          type: TransactionTypes.credit,
          amountPiasters: 12345,
          transactionDate: statementNow,
          note: 'Active note',
        );
        await db.transactionDao.createTransaction(
          customerId: id,
          type: TransactionTypes.credit,
          amountPiasters: 500,
          transactionDate: DateTime(2026, 9, 1),
          note: 'Older active note',
        );
        final deleted = await db.transactionDao.createTransaction(
          customerId: id,
          type: TransactionTypes.credit,
          amountPiasters: 99999,
          transactionDate: statementNow,
          note: 'Deleted note',
        );
        await db.transactionDao.softDeleteTransaction(deleted.id);
      });
      source = StatementRepositoryImpl(
        db.customerDao,
        db.transactionDao,
        _Dates(),
        errors,
      );
      await pump(tester, id: id, settle: false);
      await tester.runAsync(() async {
        if (cubit.state.loading) {
          await cubit.stream
              .firstWhere((state) => !state.loading)
              .timeout(const Duration(seconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Active note'), findsOneWidget);
      expect(find.text('Deleted note'), findsNothing);
      expect(cubit.state.statement!.balancePiasters, 12845);
      await tester.ensureVisible(
        find.byKey(const ValueKey('statement-range-2')),
      );
      await tester.tap(find.byKey(const ValueKey('statement-range-2')));
      await tester.pump();
      await tester.runAsync(() async {
        if (cubit.state.loading) {
          await cubit.stream
              .firstWhere((state) => !state.loading)
              .timeout(const Duration(seconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Older active note'), findsNothing);
      expect(cubit.state.statement!.balancePiasters, 12845);
      expect(cubit.state.statement!.periodCreditPiasters, 12345);
      await tapAction(tester, 'statement-copy');
      expect(copied, contains('Active note'));
      expect(copied, isNot(contains('Deleted note')));
    },
  );

  testWidgets('narrow RTL large text does not overflow', (tester) async {
    await pump(tester, locale: 'ar', mode: ThemeMode.dark);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tapAction(tester, 'statement-copy');
    expect(tester.takeException(), isNull);
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

  test('WhatsApp foreground is readable in both themes', () {
    for (final colors in [AppColorScheme.light, AppColorScheme.dark]) {
      expect(
        (colors.whatsappColor.computeLuminance() + .05) /
            (colors.onWhatsappColor.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
