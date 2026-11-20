import 'dart:collection';
import 'dart:convert';

import 'package:daftariapp/features/security/data/services/pbkdf2_sha256.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

final class _CountingBytes extends ListBase<int> {
  _CountingBytes(this.bytes);

  final List<int> bytes;
  int reads = 0;

  @override
  int get length => bytes.length;
  @override
  set length(int value) => throw UnsupportedError('Read only');
  @override
  int operator [](int index) {
    reads++;
    return bytes[index];
  }

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('Read only');
}

void main() {
  test('RFC 7914 section 11, c=1 and two output blocks', () {
    expect(
      _hex(
        Pbkdf2Sha256.deriveKey(
          password: 'passwd',
          salt: utf8.encode('salt'),
          iterations: 1,
          length: 64,
        ),
      ),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
  });

  test('RFC 7914 section 11, c=80000', () {
    expect(
      _hex(
        Pbkdf2Sha256.deriveKey(
          password: 'Password',
          salt: utf8.encode('NaCl'),
          iterations: 80000,
          length: 64,
        ),
      ),
      '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
      'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
    );
  });

  // Independent Python hashlib.pbkdf2_hmac('sha256', ...) outputs.
  final vectors = [
    (
      'password',
      'salt',
      2,
      32,
      'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
    ),
    (
      'password',
      'salt',
      4096,
      32,
      'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    ),
    (
      'pass\u0000word',
      'sa\u0000lt',
      4096,
      16,
      '89b69d0516f829893c696226650a8687',
    ),
    (
      'p' * 65,
      's' * 52,
      3,
      33,
      'ba672c9dc4052475c0ead538d4ffbc56fe6ddc7b2f10ead7f9d50dfab434a2533b',
    ),
    (
      'p' * 64,
      's' * 51,
      2,
      31,
      'd3abfa5fcfeacd1e393dbe47944052e156fd20c9a853f5fb3ab78dda1001a3',
    ),
    (
      'p' * 131,
      's' * 64,
      2,
      65,
      '856d6d91310fefe45759482395616e0da15cbc52ee13aae63d7101a44673b374f'
          'c200b274f892913a9019a004d8260bc082580c7033bc732b6aefb5467376974a2',
    ),
    (
      'دفتري',
      'ملح',
      2,
      32,
      '8090b296a82978906c616e3c7dad5f15d935b08f247a4fa15c495c67f953d264',
    ),
    (
      '',
      '',
      1,
      32,
      'f7ce0b653d2d72a4108cf5abe912ffdd777616dbbb27a70e8204f3ae2d0f6fad',
    ),
  ];
  for (var index = 0; index < vectors.length; index++) {
    test(
      'independent vector $index (padding, long keys, UTF-8, truncation)',
      () {
        final vector = vectors[index];
        expect(
          _hex(
            Pbkdf2Sha256.deriveKey(
              password: vector.$1,
              salt: utf8.encode(vector.$2),
              iterations: vector.$3,
              length: vector.$4,
            ),
          ),
          vector.$5,
        );
      },
    );
  }

  test('rejects invalid work parameters and non-byte salts', () {
    for (final iterations in [0, -1]) {
      expect(
        () => Pbkdf2Sha256.deriveKey(
          password: 'p',
          salt: [],
          iterations: iterations,
          length: 32,
        ),
        throwsFormatException,
      );
    }
    for (final length in [0, -1, 1025]) {
      expect(
        () => Pbkdf2Sha256.deriveKey(
          password: 'p',
          salt: [],
          iterations: 1,
          length: length,
        ),
        throwsFormatException,
      );
    }
    for (final byte in [-1, 256]) {
      expect(
        () => Pbkdf2Sha256.deriveKey(
          password: 'p',
          salt: [byte],
          iterations: 1,
          length: 32,
        ),
        throwsFormatException,
      );
    }
  });

  test('comparison checks every byte for first/middle/last mismatches', () {
    for (final mismatch in [-1, 0, 16, 31]) {
      final left = _CountingBytes(List.filled(32, 123));
      final rightBytes = List.filled(32, 123);
      if (mismatch >= 0) rightBytes[mismatch] = 124;
      final right = _CountingBytes(rightBytes);
      expect(Pbkdf2Sha256.constantTimeEquals(left, right), mismatch == -1);
      expect(left.reads, 32);
      expect(right.reads, 32);
    }
    expect(Pbkdf2Sha256.constantTimeEquals([], []), isTrue);
    expect(Pbkdf2Sha256.constantTimeEquals([0], [0, 0]), isFalse);
    expect(Pbkdf2Sha256.constantTimeEquals([0, 255], [0, 255]), isTrue);
  });
}
