import 'package:daftariapp/features/security/data/services/pbkdf2_sha256.dart';
import 'package:daftariapp/features/security/data/services/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verifies an independently generated production-profile fixture', () async {
    // Python hashlib.pbkdf2_hmac('sha256', b'0123', bytes(range(16)), 600000).
    const hex =
        'dc496ed5815692367dfff09d531b5f961ea3042c45f495187f6d8d3be476ef41';
    final salt = List<int>.generate(16, (index) => index);
    final verifier = List<int>.generate(
      32,
      (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
    );
    expect(
      await PinHasher.verify('0123', PinHash(salt: salt, verifier: verifier)),
      isTrue,
    );
    final alteredSalt = [...salt]..[0] ^= 1;
    expect(
      await PinHasher.verify(
        '0123',
        PinHash(salt: alteredSalt, verifier: verifier),
      ),
      isFalse,
    );
    final alteredVerifier = [...verifier]..[31] ^= 1;
    expect(
      await PinHasher.verify(
        '0123',
        PinHash(salt: salt, verifier: alteredVerifier),
      ),
      isFalse,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('production profile generates unique salts and verifies PINs', () async {
    final first = await PinHasher.hash('0123');
    final second = await PinHasher.hash('0123');
    expect(first.version, 1);
    expect(first.iterations, 600000);
    expect(first.salt.length, 16);
    expect(first.verifier.length, 32);
    expect(first.salt, isNot(second.salt));
    expect(first.verifier, isNot(second.verifier));
    expect(await PinHasher.verify('0123', first), isTrue);
    expect(await PinHasher.verify('1230', first), isFalse);
    expect(await PinHasher.verify('0123\n', first), isFalse);
    expect(await PinHasher.verify('١٢٣٤', first), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('verifier rehydration defensively copies and redacts secrets', () {
    final salt = List<int>.generate(16, (index) => index);
    final verifier = List<int>.generate(32, (index) => index);
    final hash = PinHash(salt: salt, verifier: verifier);
    salt[0] = 255;
    verifier[0] = 255;
    expect(hash.salt[0], 0);
    expect(hash.verifier[0], 0);
    expect(() => hash.salt[0] = 1, throwsUnsupportedError);
    expect(() => hash.verifier[0] = 1, throwsUnsupportedError);
    expect(hash.toString(), 'PinHash(redacted)');
  });

  test('rejects unsupported profiles and malformed stored verifier bytes', () {
    final salt = List.filled(16, 0);
    final verifier = List.filled(32, 0);
    expect(
      () => PinHash(salt: salt, verifier: verifier, version: 2),
      throwsFormatException,
    );
    for (final iterations in [0, 1, 599999, 600001, 999999999]) {
      expect(
        () => PinHash(salt: salt, verifier: verifier, iterations: iterations),
        throwsFormatException,
      );
    }
    for (final invalid in [
      <int>[],
      List.filled(15, 0),
      List.filled(17, 0),
      List.filled(16, -1),
      List.filled(16, 256),
    ]) {
      expect(
        () => PinHash(salt: invalid, verifier: verifier),
        throwsFormatException,
      );
    }
    for (final invalid in [
      <int>[],
      List.filled(31, 0),
      List.filled(33, 0),
      List.filled(32, -1),
      List.filled(32, 256),
    ]) {
      expect(
        () => PinHash(salt: salt, verifier: invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'hash rejects invalid PINs without exposing input in exceptions',
    () async {
      for (final pin in ['', '123', '12345', '1234\n', 'sensitive-input']) {
        await expectLater(
          PinHasher.hash(pin),
          throwsA(
            isA<FormatException>()
                .having((error) => error.source, 'source', isNull)
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(contains(pin.isEmpty ? '""' : pin)),
                ),
          ),
        );
      }
    },
  );

  test('profile bytes compare without prefix acceptance', () {
    expect(
      Pbkdf2Sha256.constantTimeEquals(List.filled(32, 0), List.filled(31, 0)),
      isFalse,
    );
  });
}
