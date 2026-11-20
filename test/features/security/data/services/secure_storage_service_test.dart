import 'dart:convert';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/features/security/data/models/security_record.dart';
import 'package:daftariapp/features/security/data/services/pin_hasher.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = FlutterSecureStorage();
  const service = SecureStorageService(plugin);
  final hash = PinHash(
    salt: List.filled(16, 17),
    verifier: List.filled(32, 29),
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({'unrelated': 'keep'}));

  test('round trip writes one namespaced record without plaintext', () async {
    expect(await service.read(), isNull);
    final record = SecurityRecord(
      hash: hash,
      biometricEnabled: true,
      lockout: PinLockoutState(
        failedAttempts: 5,
        lockoutUntil: DateTime.utc(2026, 11, 20),
      ),
    );
    await service.write(record);
    expect((await service.read())!.toJson(), record.toJson());
    final all = await plugin.readAll();
    expect(
      all.keys,
      unorderedEquals(['unrelated', SecureStorageService.recordKey]),
    );
    expect(all['unrelated'], 'keep');
    final json = jsonDecode(all[SecureStorageService.recordKey]!) as Map;
    expect(json.keys, isNot(contains('pin')));
    expect(record.toString(), 'SecurityRecord(redacted)');
    // Disabling replaces only our record, never deleteAll or ledger data.
    await service.write(SecurityRecord());
    expect((await service.read())!.hash, isNull);
    expect(await plugin.read(key: 'unrelated'), 'keep');
  });

  test(
    'all missing, malformed and unsupported metadata fails closed',
    () async {
      final valid = SecurityRecord(hash: hash).toJson();
      final corrupt = <Object?>[
        [],
        1,
        null,
        {},
        {...valid, 'schema': 2},
        {...valid, 'schema': 1.0},
        {...valid}..remove('revision'),
        {...valid, 'revision': -1},
        {...valid}..remove('credential'),
        {...valid}..remove('lockoutUntil'),
        {...valid, 'biometricEnabled': 'true'},
        {...valid, 'failedAttempts': 5},
        {...valid, 'failedAttempts': -1},
        {...valid, 'lockoutUntil': 0},
        {
          ...valid,
          'credential': {'version': 1},
        },
        {
          ...valid,
          'credential': {...hashJson(hash), 'iterations': 1},
        },
        {
          ...valid,
          'credential': {
            ...hashJson(hash),
            'salt': [0],
          },
        },
        {
          ...valid,
          'credential': {...hashJson(hash), 'verifier': List.filled(32, 256)},
        },
        {...valid, 'credential': null, 'biometricEnabled': true},
        {...valid, 'credential': null, 'failedAttempts': 1},
      ];
      for (final value in corrupt) {
        await plugin.write(
          key: SecureStorageService.recordKey,
          value: jsonEncode(value),
        );
        await expectLater(service.read(), throwsA(isA<StorageException>()));
      }
      await plugin.write(
        key: SecureStorageService.recordKey,
        value: 'private invalid json',
      );
      await expectLater(service.read(), throwsA(isA<StorageException>()));
    },
  );

  test('raw plugin failures never escape or reset storage', () async {
    final plugin = _MockStorage();
    final service = SecureStorageService(plugin);
    when(() => plugin.read(key: SecureStorageService.recordKey))
        .thenThrow(Exception('PIN and secret verifier'));
    when(
      () => plugin.write(
        key: SecureStorageService.recordKey,
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception('PIN and secret verifier'));
    await expectLater(service.read(), throwsA(isA<StorageException>()));
    await expectLater(
      service.write(SecurityRecord()),
      throwsA(isA<StorageException>()),
    );
    verifyNever(() => plugin.deleteAll());
  });
}

Map<String, dynamic> hashJson(PinHash hash) => {
  'version': hash.version,
  'iterations': hash.iterations,
  'salt': hash.salt,
  'verifier': hash.verifier,
};
