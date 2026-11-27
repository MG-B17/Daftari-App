import 'dart:async';
import 'dart:convert';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/date/date_service.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/features/security/data/models/security_record.dart';
import 'package:daftariapp/features/security/data/repositories/security_repository_impl.dart';
import 'package:daftariapp/features/security/data/services/biometric_auth_service.dart';
import 'package:daftariapp/features/security/data/services/pin_hasher.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/security/domain/entities/pin_verify_result.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:drift/native.dart';

class _MockBiometrics extends Mock implements BiometricAuthService {}

class _Clock implements DateService {
  DateTime time = DateTime.utc(2026, 11, 20);
  @override
  DateTime now() => time;
}

class _Storage extends SecureStorageService {
  _Storage() : super(const FlutterSecureStorage());
  SecurityRecord? record;
  bool failRead = false;
  bool failWrite = false;
  final writes = <SecurityRecord>[];
  @override
  Future<SecurityRecord?> read() async {
    if (failRead) throw Exception('private read error');
    // Rehydrate to exercise serialization on every read/restart.
    return record == null ? null : SecurityRecord.fromJson(record!.toJson());
  }

  @override
  Future<void> write(SecurityRecord value) async {
    if (failWrite) throw Exception('private write error');
    record = SecurityRecord.fromJson(value.toJson());
    writes.add(record!);
  }
}

T _right<T>(Either<AppFailure, T> result) => result.fold(
  (failure) => throw StateError('Unexpected ${failure.code}'),
  (value) => value,
);

AppFailure _left<T>(Either<AppFailure, T> result) => result.fold(
  (failure) => failure,
  (_) => throw StateError('Expected failure'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late _MockBiometrics bio;
  late _Clock clock;
  late SharedPreferences prefs;
  late LocalStorageService local;
  late SecurityRepositoryImpl repository;
  late ErrorHandler errors;
  late List<String> logs;
  var hashes = 0;
  var verifies = 0;

  Future<PinHash> hash(String pin) async {
    hashes++;
    return PinHash(
      salt: List.filled(16, hashes % 256),
      verifier: List.filled(32, int.parse(pin) % 256),
    );
  }

  SecurityRepositoryImpl create({
    Future<bool> Function(String, PinHash)? verify,
  }) => SecurityRepositoryImpl(
    storage,
    bio,
    local,
    clock,
    errors,
    hashPin: hash,
    verifyHash:
        verify ??
        (pin, stored) async {
          verifies++;
          return int.parse(pin) % 256 == stored.verifier.first;
        },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'unrelated': 'ledger-marker'});
    prefs = await SharedPreferences.getInstance();
    local = LocalStorageService(prefs);
    storage = _Storage();
    bio = _MockBiometrics();
    clock = _Clock();
    logs = [];
    hashes = 0;
    verifies = 0;
    errors = ErrorHandler(AppLogger(output: logs.add));
    when(() => bio.authenticateWithBiometrics()).thenAnswer((_) async => true);
    when(() => bio.authenticateWithDeviceCredential())
        .thenAnswer((_) async => true);
    when(() => bio.canAuthenticateWithBiometrics())
        .thenAnswer((_) async => true);
    when(() => bio.isDeviceLockSupported()).thenAnswer((_) async => true);
    repository = create();
  });

  Future<void> setup() async => _right(await repository.setupPin('0123'));

  test('OS reset grant is single-use, revision-bound and expires', () async {
    await setup();
    expect(_right(await repository.authorizePinReset()), isTrue);
    _right(await repository.resetPinWithDeviceCredential('0456'));
    verify(() => bio.authenticateWithDeviceCredential()).called(1);
    when(() => bio.authenticateWithDeviceCredential())
        .thenAnswer((_) async => false);
    expect(
      _right(await repository.resetPinWithDeviceCredential('0789')),
      isFalse,
    );
    when(() => bio.authenticateWithDeviceCredential())
        .thenAnswer((_) async => true);
    _right(await repository.authorizePinReset());
    clock.time = clock.time.add(const Duration(minutes: 2));
    when(() => bio.authenticateWithDeviceCredential())
        .thenAnswer((_) async => false);
    expect(
      _right(await repository.resetPinWithDeviceCredential('0789')),
      isFalse,
    );
  });

  test(
    'background cancellation invalidates even an in-flight recovery prompt',
    () async {
      await setup();
      final started = Completer<void>();
      final answer = Completer<bool>();
      when(() => bio.authenticateWithDeviceCredential()).thenAnswer((_) {
        started.complete();
        return answer.future;
      });
      final authorization = repository.authorizePinReset();
      await started.future;
      repository.cancelPinReset();
      answer.complete(true);
      expect(_right(await authorization), isFalse);
      when(() => bio.authenticateWithDeviceCredential())
          .thenAnswer((_) async => false);
      expect(
        _right(await repository.resetPinWithDeviceCredential('0456')),
        isFalse,
      );
      expect(_right(await repository.verifyPin('0123')), const PinVerified());
    },
  );

  test(
    'a changed credential revision invalidates recovery authorization',
    () async {
      await setup();
      _right(await repository.authorizePinReset());
      _right(await repository.changePin(currentPin: '0123', newPin: '0456'));
      when(() => bio.authenticateWithDeviceCredential())
          .thenAnswer((_) async => false);
      expect(
        _right(await repository.resetPinWithDeviceCredential('0789')),
        isFalse,
      );
    },
  );

  test('all security changes preserve actual offline ledger rows and audit history', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final customer = await database.customerDao.createCustomer(
      name: 'Local ledger',
    );
    await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.credit,
      amountPiasters: 12000,
    );
    Future<List<List<Map<String, Object?>>>> snapshot() async => [
      for (final table in [
        'customers',
        'transactions',
        'transaction_audit_logs',
      ])
        (await database.customSelect('SELECT * FROM $table').get())
            .map((row) => row.data)
            .toList(),
    ];
    final before = await snapshot();
    await setup();
    _right(await repository.setBiometricEnabled(true));
    _right(await repository.setAutoLockTimeout(AutoLockTimeout.fiveMinutes));
    _right(await repository.changePin(currentPin: '0123', newPin: '0456'));
    _right(await repository.authorizePinReset());
    _right(await repository.resetPinWithDeviceCredential('0789'));
    _right(await repository.disablePin('0789'));
    expect(await snapshot(), before);
  });

  test(
    'defaults; setup stores only verifier; setup cannot overwrite PIN',
    () async {
      expect(_right(await repository.getSettings()), const SecuritySettings());
      expect(
        _right(await repository.verifyPin('0123')),
        const PinNotConfigured(),
      );
      await setup();
      expect(_right(await repository.getSettings()).isPinEnabled, isTrue);
      expect(storage.record!.hash, isNotNull);
      expect(jsonEncode(storage.record!.toJson()), isNot(contains('0123')));
      expect(local.securityInitialized, isTrue);
      expect(
        _left(await repository.setupPin('0456')).errorCode,
        AppErrorCode.auth,
      );
      expect(hashes, 1);
      expect(
        prefs.getKeys(),
        unorderedEquals([
          'unrelated',
          'securityInitialized',
          'securityRevision',
        ]),
      );
      expect(prefs.getString('unrelated'), 'ledger-marker');
    },
  );

  test('invalid PINs do not hash, consume attempts or prompt OS', () async {
    await setup();
    final original = storage.record!.toJson();
    expect(_right(await repository.verifyPin('١٢٣٤')), const PinInvalid());
    expect(
      _left(await repository.changePin(currentPin: '0000', newPin: 'bad'))
          .errorCode,
      AppErrorCode.validation,
    );
    expect(
      _left(await repository.resetPinWithDeviceCredential('bad')).errorCode,
      AppErrorCode.validation,
    );
    expect(verifies, 0);
    expect(hashes, 1);
    expect(storage.record!.toJson(), original);
    verifyNever(() => bio.authenticateWithDeviceCredential());
  });

  test(
    'lockout persists across restart; no PIN/biometric bypass or extension',
    () async {
      await setup();
      _right(await repository.setBiometricEnabled(true));
      for (var attempt = 1; attempt < 5; attempt++) {
        expect(
          _right(await repository.verifyPin('9999')),
          PinIncorrect(remainingAttempts: 5 - attempt),
        );
      }
      final deadline = clock.time.add(const Duration(seconds: 30));
      expect(
        _right(await repository.verifyPin('9999')),
        PinLockedOut(until: deadline),
      );
      repository = create();
      clock.time = clock.time.add(const Duration(seconds: 29));
      expect(_right(await repository.getLockoutState()).failedAttempts, 5);
      expect(
        _right(await repository.verifyPin('0123')),
        PinLockedOut(until: deadline),
      );
      expect(
        _right(await repository.verifyPin('bad')),
        PinLockedOut(until: deadline),
      );
      expect(
        _right(await repository.changePin(currentPin: '0123', newPin: '0456')),
        PinLockedOut(until: deadline),
      );
      expect(
        _right(await repository.disablePin('0123')),
        PinLockedOut(until: deadline),
      );
      expect(_right(await repository.authenticateWithBiometrics()), isFalse);
      expect(_right(await repository.setBiometricEnabled(true)), isFalse);
      expect(storage.record!.lockout.lockoutUntil, deadline);
      expect(verifies, 5);
      verify(() => bio.authenticateWithBiometrics())
          .called(1); // enrollment only
      clock.time = deadline;
      expect(
        _right(await repository.getLockoutState()),
        const PinLockoutState.clear(),
      );
      expect(storage.record!.lockout, const PinLockoutState.clear());
      expect(_right(await repository.verifyPin('0123')), const PinVerified());
    },
  );

  test('correct fifth attempt succeeds and clears reserved failure', () async {
    await setup();
    for (var attempt = 0; attempt < 4; attempt++) {
      _right(await repository.verifyPin('9999'));
    }
    expect(_right(await repository.verifyPin('0123')), const PinVerified());
    expect(storage.record!.lockout, const PinLockoutState.clear());
    expect(storage.writes[storage.writes.length - 2].lockout.failedAttempts, 5);
  });

  test(
    'success resets attempts; change and disable require verification',
    () async {
      await setup();
      _right(await repository.setBiometricEnabled(true));
      expect(
        _right(await repository.changePin(currentPin: '9999', newPin: '0456')),
        const PinIncorrect(remainingAttempts: 4),
      );
      expect(hashes, 1);
      expect(
        _right(await repository.changePin(currentPin: '0123', newPin: '0456')),
        const PinVerified(),
      );
      expect(hashes, 2);
      expect(storage.record!.lockout, const PinLockoutState.clear());
      expect(_right(await repository.verifyPin('0123')), isA<PinIncorrect>());
      expect(_right(await repository.disablePin('0123')), isA<PinIncorrect>());
      expect(_right(await repository.disablePin('0456')), const PinVerified());
      expect(
        _right(await repository.getSettings()).isBiometricEnabled,
        isFalse,
      );
      expect(storage.record!.hash, isNull);
      expect(storage.record!.lockout, const PinLockoutState.clear());
      expect(local.securityInitialized, isTrue); // durable disabled tombstone
      expect(prefs.getString('unrelated'), 'ledger-marker');
    },
  );

  test(
    'biometric preference is secure, enrollment needs OS success and PIN',
    () async {
      expect(_right(await repository.setBiometricEnabled(true)), isFalse);
      expect(_right(await repository.authenticateWithBiometrics()), isFalse);
      await setup();
      expect(_right(await repository.authenticateWithBiometrics()), isFalse);
      when(() => bio.authenticateWithBiometrics())
          .thenAnswer((_) async => false);
      expect(_right(await repository.setBiometricEnabled(true)), isFalse);
      expect(storage.record!.biometricEnabled, isFalse);
      when(() => bio.authenticateWithBiometrics())
          .thenAnswer((_) async => true);
      expect(_right(await repository.setBiometricEnabled(true)), isTrue);
      _right(await repository.verifyPin('9999'));
      expect(_right(await create().authenticateWithBiometrics()), isTrue);
      expect(storage.record!.lockout, const PinLockoutState.clear());
      expect(_right(await repository.setBiometricEnabled(false)), isTrue);
      expect(storage.record!.biometricEnabled, isFalse);
      expect(prefs.getKeys(), isNot(contains('biometricEnabled')));
    },
  );

  test(
    'recovery requires OS challenge; cancel preserves PIN and cooldown',
    () async {
      await setup();
      _right(await repository.setBiometricEnabled(true));
      for (var i = 0; i < 5; i++) {
        _right(await repository.verifyPin('9999'));
      }
      final original = storage.record!.toJson();
      when(() => bio.authenticateWithDeviceCredential())
          .thenAnswer((_) async => false);
      expect(
        _right(await repository.resetPinWithDeviceCredential('0456')),
        isFalse,
      );
      expect(storage.record!.toJson(), original);
      expect(hashes, 1);
      when(() => bio.authenticateWithDeviceCredential())
          .thenAnswer((_) async => true);
      expect(
        _right(await repository.resetPinWithDeviceCredential('0456')),
        isTrue,
      );
      expect(storage.record!.biometricEnabled, isFalse);
      expect(storage.record!.lockout, const PinLockoutState.clear());
      expect(_right(await repository.verifyPin('0456')), const PinVerified());
      expect(prefs.getString('unrelated'), 'ledger-marker');
    },
  );

  test('no configured PIN means no recovery prompt', () async {
    expect(
      _right(await repository.resetPinWithDeviceCredential('0456')),
      isFalse,
    );
    verifyNever(() => bio.authenticateWithDeviceCredential());
  });

  test(
    'timeout preference survives restart with safe immediate fallback',
    () async {
      for (final timeout in AutoLockTimeout.values) {
        _right(await repository.setAutoLockTimeout(timeout));
        expect(_right(await create().getSettings()).autoLockTimeout, timeout);
      }
      await prefs.setString('securityAutoLockTimeout', 'bad');
      expect(
        _right(await repository.getSettings()).autoLockTimeout,
        AutoLockTimeout.immediate,
      );
    },
  );

  test(
    'missing initialized record and storage read errors fail closed privately',
    () async {
      await local.markSecurityInitialized();
      expect(
        _left(await repository.getSettings()).errorCode,
        AppErrorCode.storage,
      );
      expect(
        _left(await repository.setupPin('0123')).errorCode,
        AppErrorCode.storage,
      );
      storage.failRead = true;
      expect(
        _left(await repository.verifyPin('0123')).errorCode,
        AppErrorCode.storage,
      );
      expect(
        _left(await repository.authenticateWithBiometrics()).errorCode,
        AppErrorCode.storage,
      );
      expect(logs, isEmpty);
      expect(hashes, 0);
    },
  );

  test('failed reservation never hashes or authenticates; write failure latches closed', () async {
    await setup();
    storage.failWrite = true;
    expect(
      _left(await repository.verifyPin('0123')).errorCode,
      AppErrorCode.storage,
    );
    expect(verifies, 0);
    storage.failWrite = false;
    expect(
      _left(await repository.verifyPin('0123')).errorCode,
      AppErrorCode.storage,
    );
    expect(
      _left(await repository.resetPinWithDeviceCredential('0456')).errorCode,
      AppErrorCode.storage,
    );
    expect(logs, isEmpty);
  });

  test(
    'concurrent wrong attempts serialize; sixth request cannot sneak through',
    () async {
      await setup();
      final results = await Future.wait(
        List.generate(6, (_) => repository.verifyPin('9999')),
      );
      expect(results.take(4).map(_right), everyElement(isA<PinIncorrect>()));
      expect(_right(results[4]), isA<PinLockedOut>());
      expect(_right(results[5]), isA<PinLockedOut>());
      expect(verifies, 5);
      expect(storage.record!.lockout.failedAttempts, 5);
    },
  );

  test(
    'lost secure write is detected after restart by committed revision',
    () async {
      await setup();
      final oldRecord = storage.record;
      _right(await repository.verifyPin('9999'));
      // Model an abrupt process kill before Android apply() reaches disk.
      storage.record = oldRecord;
      repository = create();
      expect(
        _left(await repository.getSettings()).errorCode,
        AppErrorCode.storage,
      );
      expect(
        _left(await repository.verifyPin('0123')).errorCode,
        AppErrorCode.storage,
      );
      expect(
        _left(await repository.setupPin('0456')).errorCode,
        AppErrorCode.storage,
      );
      expect(logs, isEmpty);
    },
  );

  test(
    'final success write failure returns no authorization and stays closed',
    () async {
      await setup();
      repository = create(
        verify: (_, _) async {
          storage.failWrite = true;
          return true;
        },
      );
      expect(
        _left(await repository.verifyPin('0123')).errorCode,
        AppErrorCode.storage,
      );
      storage.failWrite = false;
      expect(storage.record!.lockout.failedAttempts, 1);
      expect(
        _left(await create().verifyPin('0123')).errorCode,
        AppErrorCode.storage,
      );
    },
  );

  test('failed setup cannot become PIN-disabled on restart', () async {
    storage.failWrite = true;
    expect(
      _left(await repository.setupPin('0123')).errorCode,
      AppErrorCode.storage,
    );
    storage.failWrite = false;
    expect(_left(await create().getSettings()).errorCode, AppErrorCode.storage);
    expect(storage.record, isNull);
  });

  test('biometric cancellation preserves existing failed attempts', () async {
    await setup();
    _right(await repository.setBiometricEnabled(true));
    _right(await repository.verifyPin('9999'));
    final before = storage.record!.toJson();
    when(() => bio.authenticateWithBiometrics()).thenAnswer((_) async => false);
    expect(_right(await repository.authenticateWithBiometrics()), isFalse);
    expect(storage.record!.toJson(), before);
  });

  test('capabilities pass through without persisting or prompting', () async {
    expect(_right(await repository.canAuthenticateWithBiometrics()), isTrue);
    expect(_right(await repository.isDeviceLockSupported()), isTrue);
    expect(storage.writes, isEmpty);
    verifyNever(() => bio.authenticateWithBiometrics());
    verifyNever(() => bio.authenticateWithDeviceCredential());
  });

  test('attempt persists before hash completes; restart preserves interrupted attempt', () async {
    await setup();
    final started = Completer<void>();
    final finish = Completer<bool>();
    repository = create(
      verify: (_, _) {
        started.complete();
        return finish.future;
      },
    );
    final operation = repository.verifyPin('9999');
    await started.future;
    expect(storage.record!.lockout.failedAttempts, 1);
    expect(_right(await create().getLockoutState()).failedAttempts, 1);
    finish.complete(false);
    expect(_right(await operation), const PinIncorrect(remainingAttempts: 4));
  });

  test('credential changes and OS prompts cannot race', () async {
    await setup();
    final started = Completer<void>();
    final finish = Completer<bool>();
    when(() => bio.authenticateWithDeviceCredential()).thenAnswer((_) {
      started.complete();
      return finish.future;
    });
    final recovery = repository.resetPinWithDeviceCredential('0456');
    await started.future;
    final oldPin = repository.disablePin('0123');
    finish.complete(true);
    expect(_right(await recovery), isTrue);
    expect(_right(await oldPin), isA<PinIncorrect>());
    expect(storage.record!.hash, isNotNull);
  });
}
