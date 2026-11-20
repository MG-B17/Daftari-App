import 'dart:convert';
import 'dart:typed_data';

/// PBKDF2-HMAC-SHA256 for the fixed PIN hashing profile and test vectors.
///
/// Uses RFC 8018's block counter and FIPS 180-4's SHA-256 compression.
/// Callers choose work factors; application PINs must use `PinHasher` instead.
abstract final class Pbkdf2Sha256 {
  static Uint8List deriveKey({
    required String password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    if (iterations < 1 || length < 1 || length > 1024) {
      throw const FormatException('Invalid PBKDF2 parameters');
    }
    if (salt.any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException('Invalid salt bytes');
    }
    final hmac = _HmacSha256(utf8.encode(password));
    final output = Uint8List(length);
    final input = Uint8List(salt.length + 4)..setAll(0, salt);
    final counter = ByteData.sublistView(input);
    for (var block = 1, offset = 0; offset < length; block++, offset += 32) {
      counter.setUint32(salt.length, block, Endian.big);
      var u = hmac.digest(input);
      final accumulated = Uint8List.fromList(u);
      for (var round = 1; round < iterations; round++) {
        u = hmac.digest(u);
        for (var i = 0; i < 32; i++) {
          accumulated[i] ^= u[i];
        }
      }
      final count = length - offset < 32 ? length - offset : 32;
      output.setRange(offset, offset + count, accumulated);
    }
    return output;
  }

  /// Compares equal-length bytes without a content-dependent early return.
  ///
  /// Lengths are public metadata. Dart VM/JIT execution is not a formal
  /// constant-time guarantee; this avoids short-circuit byte comparisons.
  static bool constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}

final class _HmacSha256 {
  _HmacSha256(List<int> key) {
    final normalized = key.length > 64 ? _hash(key) : key;
    final inner = Uint8List(64);
    final outer = Uint8List(64);
    for (var i = 0; i < 64; i++) {
      final byte = i < normalized.length ? normalized[i] : 0;
      inner[i] = byte ^ 0x36;
      outer[i] = byte ^ 0x5c;
    }
    _compress(_innerState, inner, 0, _schedule);
    _compress(_outerState, outer, 0, _schedule);
  }

  final Uint32List _innerState = Uint32List.fromList(_initialState);
  final Uint32List _outerState = Uint32List.fromList(_initialState);
  final Uint32List _schedule = Uint32List(64);

  Uint8List digest(List<int> message) {
    final inner = _finish(_innerState, message, 64, _schedule);
    return _finish(_outerState, inner, 64, _schedule);
  }
}

Uint8List _hash(List<int> input) =>
    _finish(Uint32List.fromList(_initialState), input, 0, Uint32List(64));

Uint8List _finish(
  Uint32List initial,
  List<int> input,
  int prefixLength,
  Uint32List schedule,
) {
  final state = Uint32List.fromList(initial);
  final paddedLength = ((input.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLength)..setAll(0, input);
  padded[input.length] = 0x80;
  final bits = (prefixLength + input.length) * 8;
  final data = ByteData.sublistView(padded);
  data.setUint32(paddedLength - 8, bits ~/ 0x100000000, Endian.big);
  data.setUint32(paddedLength - 4, bits & 0xffffffff, Endian.big);
  for (var offset = 0; offset < paddedLength; offset += 64) {
    _compress(state, padded, offset, schedule);
  }
  final output = Uint8List(32);
  final outputData = ByteData.sublistView(output);
  for (var i = 0; i < 8; i++) {
    outputData.setUint32(i * 4, state[i], Endian.big);
  }
  return output;
}

int _rotate(int word, int bits) =>
    ((word >>> bits) | (word << (32 - bits))) & 0xffffffff;

void _compress(
  Uint32List state,
  Uint8List block,
  int offset,
  Uint32List words,
) {
  final data = ByteData.sublistView(block);
  for (var i = 0; i < 16; i++) {
    words[i] = data.getUint32(offset + i * 4, Endian.big);
  }
  for (var i = 16; i < 64; i++) {
    final x = words[i - 15];
    final y = words[i - 2];
    final small0 = _rotate(x, 7) ^ _rotate(x, 18) ^ (x >>> 3);
    final small1 = _rotate(y, 17) ^ _rotate(y, 19) ^ (y >>> 10);
    words[i] = (words[i - 16] + small0 + words[i - 7] + small1) & 0xffffffff;
  }

  var a = state[0];
  var b = state[1];
  var c = state[2];
  var d = state[3];
  var e = state[4];
  var f = state[5];
  var g = state[6];
  var h = state[7];
  for (var i = 0; i < 64; i++) {
    final big1 = _rotate(e, 6) ^ _rotate(e, 11) ^ _rotate(e, 25);
    final choose = (e & f) ^ ((~e) & g);
    final temp1 =
        (h + big1 + choose + _roundConstants[i] + words[i]) & 0xffffffff;
    final big0 = _rotate(a, 2) ^ _rotate(a, 13) ^ _rotate(a, 22);
    final majority = (a & b) ^ (a & c) ^ (b & c);
    final temp2 = (big0 + majority) & 0xffffffff;
    h = g;
    g = f;
    f = e;
    e = (d + temp1) & 0xffffffff;
    d = c;
    c = b;
    b = a;
    a = (temp1 + temp2) & 0xffffffff;
  }
  state[0] = (state[0] + a) & 0xffffffff;
  state[1] = (state[1] + b) & 0xffffffff;
  state[2] = (state[2] + c) & 0xffffffff;
  state[3] = (state[3] + d) & 0xffffffff;
  state[4] = (state[4] + e) & 0xffffffff;
  state[5] = (state[5] + f) & 0xffffffff;
  state[6] = (state[6] + g) & 0xffffffff;
  state[7] = (state[7] + h) & 0xffffffff;
}

const _initialState = [
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
];

const _roundConstants = [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
