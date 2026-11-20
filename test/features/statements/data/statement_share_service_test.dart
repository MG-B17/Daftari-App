import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/domain/entities/share_statement_result.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late StatementShareService service;
  late List<Uri> launches;
  late List<ShareParams> shares;
  late List<String> logs;
  var launchesSuccessfully = true;
  var throwsOnLaunch = false;
  var throwsOnShare = false;
  var status = ShareResultStatus.success;
  const text = 'دفتري\nCustomer & amount + 123.45 = 50% 😀';
  const phone = '01012345678';

  setUp(() {
    launches = [];
    shares = [];
    logs = [];
    launchesSuccessfully = true;
    throwsOnLaunch = false;
    throwsOnShare = false;
    status = ShareResultStatus.success;
    service = StatementShareService(
      ErrorHandler(AppLogger(output: logs.add)),
      launcher: (uri, {required mode}) async {
        launches.add(uri);
        expect(mode, LaunchMode.externalApplication);
        if (throwsOnLaunch) {
          throw PlatformException(code: 'private', message: uri.toString());
        }
        return launchesSuccessfully;
      },
      systemShare: (params) async {
        shares.add(params);
        if (throwsOnShare) {
          throw PlatformException(code: 'private', message: params.text);
        }
        return ShareResult('private raw result', status);
      },
    );
  });

  for (final input in [
    phone,
    '+20 101 234 5678',
    '00201012345678',
    '201012345678',
    ' (010) 1234-5678 ',
    '٠١٠١٢٣٤٥٦٧٨',
    '۰۱۰۱۲۳۴۵۶۷۸',
    '01112345678',
    '01212345678',
    '01512345678',
  ]) {
    test('normalizes Egyptian phone $input', () {
      final normalized = StatementShareService.normalizePhone(input);
      expect(normalized, matches(RegExp(r'^201[0125][0-9]{8}$')));
      if (!input.startsWith('011') &&
          !input.startsWith('012') &&
          !input.startsWith('015')) {
        expect(normalized, '201012345678');
      }
    });
  }

  for (final input in [
    null,
    '',
    ' ',
    '01312345678',
    '010123',
    'abc01012345678',
    '+201012345678&text=oops',
    '010123456789',
    '+12345678901',
  ]) {
    test('invalid or missing phone falls back safely: $input', () async {
      expect(StatementShareService.normalizePhone(input), isNull);
      expect(
        await service.shareViaWhatsApp(text: text, phone: input),
        const Right<AppFailure, ShareStatementResult>(
          ShareStatementResult.systemShare,
        ),
      );
      expect(launches, isEmpty);
      expect(shares.single.text, text);
    });
  }

  test(
    'direct WhatsApp launch round-trips Unicode and reserved characters',
    () async {
      expect(
        await service.shareViaWhatsApp(text: text, phone: phone),
        const Right<AppFailure, ShareStatementResult>(
          ShareStatementResult.whatsapp,
        ),
      );
      final uri = launches.single;
      expect(uri.scheme, 'whatsapp');
      expect(uri.host, 'send');
      expect(uri.queryParameters, {'phone': '201012345678', 'text': text});
      expect(uri.toString(), contains('%20'));
      expect(shares, isEmpty);
      expect(logs, isEmpty);
    },
  );

  test('false launch falls back exactly once with unchanged text', () async {
    launchesSuccessfully = false;
    await service.shareViaWhatsApp(text: text, phone: phone);
    expect(launches, hasLength(1));
    expect(shares.single.text, text);
  });

  test('launch exception falls back without logging private URI', () async {
    throwsOnLaunch = true;
    await service.shareViaWhatsApp(text: text, phone: phone);
    expect(shares.single.text, text);
    expect(logs, isEmpty);
  });

  test('encoded URI threshold includes exactly 4000 characters', () async {
    final prefix = 'whatsapp://send?phone=201012345678&text=';
    final exact = List.filled(4000 - prefix.length, 'a').join();
    await service.shareViaWhatsApp(text: exact, phone: phone);
    expect(launches.single.toString().length, 4000);
    await service.shareViaWhatsApp(text: '${exact}a', phone: phone);
    expect(launches, hasLength(1));
    expect(shares.single.text, '${exact}a');
  });

  test('Unicode payload uses encoded length, not raw text length', () async {
    final longText = List.filled(700, 'د').join();
    await service.shareViaWhatsApp(text: longText, phone: phone);
    expect(launches, isEmpty);
    expect(shares.single.text, longText);
  });

  for (final resultStatus in ShareResultStatus.values) {
    test(
      'system share handles $resultStatus without assuming delivery',
      () async {
        status = resultStatus;
        const origin = Rect.fromLTWH(10, 20, 30, 40);
        expect(
          await service.shareViaSystem(text: text, sharePositionOrigin: origin),
          Right<AppFailure, ShareStatementResult>(
            resultStatus == ShareResultStatus.dismissed
                ? ShareStatementResult.dismissed
                : ShareStatementResult.systemShare,
          ),
        );
        expect(shares.single.sharePositionOrigin, origin);
        expect(launches, isEmpty);
        expect(logs, isEmpty);
      },
    );
  }

  test('both plugin failures return a privacy-safe failure', () async {
    throwsOnLaunch = true;
    throwsOnShare = true;
    expect(
      await service.shareViaWhatsApp(text: text, phone: phone),
      const Left<AppFailure, ShareStatementResult>(
        AppFailure(AppErrorCode.unexpected),
      ),
    );
    expect(logs, [AppErrorCode.unexpected.code]);
    expect(shares, hasLength(1));
  });

  test('empty text never invokes platform APIs', () async {
    expect(
      await service.shareViaWhatsApp(text: ' \n', phone: phone),
      const Left<AppFailure, ShareStatementResult>(
        AppFailure(AppErrorCode.validation),
      ),
    );
    expect(
      await service.shareViaSystem(text: ''),
      const Left<AppFailure, ShareStatementResult>(
        AppFailure(AppErrorCode.validation),
      ),
    );
    expect(launches, isEmpty);
    expect(shares, isEmpty);
  });
}
