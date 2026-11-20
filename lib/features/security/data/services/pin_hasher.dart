import 'dart:isolate';
import 'dart:math';

import '../../domain/policies/pin_lockout_policy.dart';
import 'pbkdf2_sha256.dart';

/// Immutable verifier metadata for the supported hashing profile.
///
/// Never contains a plaintext PIN and deliberately excludes bytes from
/// [toString]. Unsupported or malformed stored parameters must fail closed.
final class PinHash {
  factory PinHash({
    required List<int> salt,
    required List<int> verifier,
    int version = PinHasher.version,
    int iterations = PinHasher.iterations,
  }) {
    if (version != PinHasher.version ||
        iterations != PinHasher.iterations ||
        salt.length != PinHasher.saltLength ||
        verifier.length != PinHasher.verifierLength ||
        [...salt, ...verifier].any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException('Invalid PIN verifier metadata');
    }
    return PinHash._(List.unmodifiable(salt), List.unmodifiable(verifier));
  }

  const PinHash._(this.salt, this.verifier);

  final List<int> salt;
  final List<int> verifier;
  int get version => PinHasher.version;
  int get iterations => PinHasher.iterations;

  @override
  String toString() => 'PinHash(redacted)';
}

/// Creates salted PBKDF2-HMAC-SHA256 verifiers off the UI isolate.
///
/// Version 1 fixes 600,000 iterations, a 16-byte secure random salt, and a
/// 32-byte verifier. Four-digit PINs still have low entropy: secure storage
/// and persisted attempt limits remain essential.
abstract final class PinHasher {
  static const version = 1;
  static const iterations = 600000;
  static const saltLength = 16;
  static const verifierLength = 32;

  static Future<PinHash> hash(String pin) async {
    PinLockoutPolicy.validatePin(pin);
    return Isolate.run(() {
      final random = Random.secure();
      final salt = List.generate(saltLength, (_) => random.nextInt(256));
      return PinHash(
        salt: salt,
        verifier: Pbkdf2Sha256.deriveKey(
          password: pin,
          salt: salt,
          iterations: iterations,
          length: verifierLength,
        ),
      );
    });
  }

  static Future<bool> verify(String pin, PinHash hash) async {
    if (!PinLockoutPolicy.isValidPin(pin)) return false;
    return Isolate.run(() {
      final candidate = Pbkdf2Sha256.deriveKey(
        password: pin,
        salt: hash.salt,
        iterations: hash.iterations,
        length: verifierLength,
      );
      return Pbkdf2Sha256.constantTimeEquals(candidate, hash.verifier);
    });
  }
}
