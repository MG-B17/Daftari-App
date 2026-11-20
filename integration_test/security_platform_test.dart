import 'package:daftariapp/features/security/data/models/security_record.dart';
import 'package:daftariapp/features/security/data/services/biometric_auth_service.dart';
import 'package:daftariapp/features/security/data/services/pin_hasher.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android secure record and production hashing smoke test', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Separate Android namespace: never read/write the app's real credentials.
      const plugin = FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'daftari_security_platform_test',
          resetOnError: false,
        ),
      );
      const storage = SecureStorageService(plugin);
      try {
        final watch = Stopwatch()..start();
        final hash = await PinHasher.hash('0123');
        final hashMillis = watch.elapsedMilliseconds;
        final record = SecurityRecord(
          hash: hash,
          lockout: PinLockoutState(
            failedAttempts: 5,
            lockoutUntil: DateTime.now().toUtc().add(
              const Duration(seconds: 30),
            ),
          ),
        );
        await storage.write(record);
        final restored = await const SecureStorageService(plugin).read();
        expect(restored!.toJson(), record.toJson());
        watch.reset();
        expect(await PinHasher.verify('0123', restored.hash!), isTrue);
        final verifyMillis = watch.elapsedMilliseconds;
        expect(await PinHasher.verify('9999', restored.hash!), isFalse);
        // Only durations are emitted, never PINs, salts, or verifiers.
        debugPrint(
          'Security PBKDF2: hash=${hashMillis}ms verify=${verifyMillis}ms',
        );
        final platformAuth = LocalAuthentication();
        // Check the plugin directly so swallowed MissingPluginExceptions cannot
        // make this smoke test pass as an unsupported-device fallback.
        final canCheck = await platformAuth.canCheckBiometrics;
        final available = await platformAuth.getAvailableBiometrics();
        final supported = await platformAuth.isDeviceSupported();
        final auth = BiometricAuthService(
          platformAuth,
          biometricReason: () => 'Security integration test',
          recoveryReason: () => 'Security integration test',
        );
        expect(
          await auth.canAuthenticateWithBiometrics(),
          canCheck && available.isNotEmpty,
        );
        expect(await auth.isDeviceLockSupported(), supported);
      } finally {
        await plugin.delete(key: SecureStorageService.recordKey);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
