import 'dart:async';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/features/auth/session/data/repositories/auth_session_repository_impl.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/secure_gotrue_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_bootstrap.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_outcome.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/domain/entities/ledger_link_status.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth_test_fakes.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class MockGoTrueClient extends Mock implements sb.GoTrueClient {}

void main() {
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
  });

  group('SupabaseBootstrap', () {
    test(
      'degrades safely when config is missing, placeholder, or non-https',
      () async {
        var initCalls = 0;
        for (final pair in [
          ('', ''),
          ('https://your-project-ref.supabase.co', 'anon-key'),
          ('http://example.supabase.co', 'anon-key'),
          ('https://example.supabase.co', ''),
        ]) {
          final bootstrap = SupabaseBootstrap(
            url: pair.$1,
            anonKey: pair.$2,
            initializer:
                ({
                  required url,
                  required anonKey,
                  required secureStorage,
                }) async {
                  initCalls++;
                  return MockSupabaseClient();
                },
          );
          expect(bootstrap.hasValidConfig, isFalse);
          expect(await bootstrap.initialize(secureStorage), isFalse);
          expect(bootstrap.isConfigured, isFalse);
          expect(bootstrap.client, isNull);
        }
        expect(initCalls, 0);
      },
    );

    test(
      'initializes once with valid config and handles initializer error safely',
      () async {
        final client = MockSupabaseClient();
        var initCalls = 0;
        final bootstrap = SupabaseBootstrap(
          url: 'https://demo.supabase.co',
          anonKey: 'anon-key',
          initializer:
              ({required url, required anonKey, required secureStorage}) async {
                initCalls++;
                return client;
              },
        );

        expect(bootstrap.hasValidConfig, isTrue);
        expect(await bootstrap.initialize(secureStorage), isTrue);
        expect(await bootstrap.initialize(secureStorage), isTrue);
        expect(initCalls, 1);
        expect(bootstrap.isConfigured, isTrue);
        expect(bootstrap.client, same(client));

        final failing = SupabaseBootstrap(
          url: 'https://demo.supabase.co',
          anonKey: 'anon-key',
          initializer: ({
            required url,
            required anonKey,
            required secureStorage,
          }) async => throw StateError('init boom'),
        );
        expect(await failing.initialize(secureStorage), isFalse);
        expect(failing.isConfigured, isFalse);
        expect(failing.client, isNull);
      },
    );
  });

  group('SecureGotrueStorage and SecureSupabaseLocalStorage', () {
    test('scopes PKCE keys and wraps storage errors', () async {
      final storage = SecureGotrueStorage(secureStorage);
      when(
        () => secureStorage.write(
          key: '${SecureGotrueStorage.keyPrefix}verifier',
          value: 'secret-code',
        ),
      ).thenAnswer((_) async {});
      when(
        () =>
            secureStorage.read(key: '${SecureGotrueStorage.keyPrefix}verifier'),
      ).thenAnswer((_) async => 'secret-code');
      when(
        () => secureStorage.delete(
          key: '${SecureGotrueStorage.keyPrefix}verifier',
        ),
      ).thenAnswer((_) async {});

      await storage.setItem(key: 'verifier', value: 'secret-code');
      expect(await storage.getItem(key: 'verifier'), 'secret-code');
      await storage.removeItem(key: 'verifier');

      when(() => secureStorage.read(key: any(named: 'key')))
          .thenThrow(Exception('keystore locked'));
      await expectLater(
        () => storage.getItem(key: 'verifier'),
        throwsA(isA<StorageException>()),
      );
    });

    test('persists and clears session under dedicated key', () async {
      final storage = SecureSupabaseLocalStorage(secureStorage);
      expect(
        SecureSupabaseLocalStorage.sessionKey,
        isNot(SecureStorageService.recordKey),
      );
      expect(
        SecureSupabaseLocalStorage.sessionKey,
        isNot(LedgerOwnerStorage.ownerKey),
      );

      when(
        () => secureStorage.write(
          key: SecureSupabaseLocalStorage.sessionKey,
          value: '{"access_token":"t"}',
        ),
      ).thenAnswer((_) async {});
      when(() => secureStorage.read(key: SecureSupabaseLocalStorage.sessionKey))
          .thenAnswer((_) async => '{"access_token":"t"}');
      when(
        () => secureStorage.delete(key: SecureSupabaseLocalStorage.sessionKey),
      ).thenAnswer((_) async {});

      await storage.initialize();
      await storage.persistSession('{"access_token":"t"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), '{"access_token":"t"}');
      await storage.removePersistedSession();
    });
  });

  group('LedgerOwnerStorage', () {
    test('uses isolated key, trims owner ID, rejects blank, preserves first owner, wraps errors', () async {
      expect(LedgerOwnerStorage.ownerKey, 'daftari.auth.ledger_owner.v1');
      expect(
        LedgerOwnerStorage.ownerKey,
        isNot(SecureStorageService.recordKey),
      );

      final storage = LedgerOwnerStorage(secureStorage);
      String? storedOwner;
      var writeCalls = 0;
      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => storedOwner);
      when(
        () => secureStorage.write(
          key: LedgerOwnerStorage.ownerKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        writeCalls++;
        storedOwner = invocation.namedArguments[#value] as String?;
      });

      expect(await storage.readOwnerId(), isNull);
      expect(await storage.claimOwnerId('  user-a '), 'user-a');
      expect(writeCalls, 1);
      expect(await storage.readOwnerId(), 'user-a');

      expect(await storage.claimOwnerId('user-a'), 'user-a');
      expect(writeCalls, 1);

      expect(await storage.claimOwnerId('user-b'), 'user-a');
      expect(writeCalls, 1);
      expect(await storage.readOwnerId(), 'user-a');

      await expectLater(
        () => storage.claimOwnerId('   '),
        throwsA(isA<ValidationException>()),
      );

      storedOwner = '   ';
      expect(await storage.readOwnerId(), isNull);

      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenThrow(Exception('boom'));
      await expectLater(storage.readOwnerId, throwsA(isA<StorageException>()));
    });

    test('serializes interleaved first-link requests so only one owner is committed', () async {
      final storage = LedgerOwnerStorage(secureStorage);
      String? storedOwner;
      var writeCalls = 0;
      final firstWriteStarted = Completer<void>();
      final allowFirstWriteToFinish = Completer<void>();

      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => storedOwner);
      when(
        () => secureStorage.write(
          key: LedgerOwnerStorage.ownerKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        writeCalls++;
        final value = invocation.namedArguments[#value] as String?;
        if (!firstWriteStarted.isCompleted) {
          firstWriteStarted.complete();
          await allowFirstWriteToFinish.future;
        }
        storedOwner = value;
      });

      final first = storage.claimOwnerId('user-a');
      await firstWriteStarted.future;
      final second = storage.claimOwnerId('user-b');
      allowFirstWriteToFinish.complete();

      expect(await first, 'user-a');
      expect(await second, 'user-a');
      expect(writeCalls, 1);
      expect(storedOwner, 'user-a');
    });
  });

  group('SupabaseAuthService unconfigured mode', () {
    test('degrades safely without blocking offline usage', () async {
      final bootstrap = SupabaseBootstrap(url: '', anonKey: '');
      await bootstrap.initialize(secureStorage);
      final service = SupabaseAuthService(bootstrap);

      expect(service.isConfigured, isFalse);
      expect(await service.getCurrentUser(), isNull);
      expect(await service.watchAuthChanges().toList(), isEmpty);
      await service.signOut();

      await expectLater(
        () => service.signInWithPassword(
          email: 'owner@shop.com',
          password: 'password1',
        ),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        () => service.sendPasswordResetEmail('owner@shop.com'),
        throwsA(isA<AuthException>()),
      );
    });

    test('maps email_not_confirmed to unverified AuthUser and rethrows invalid_credentials', () async {
      final client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);

      final bootstrap = SupabaseBootstrap(
        url: 'https://demo.supabase.co',
        anonKey: 'anon-key',
        initializer: ({
          required url,
          required anonKey,
          required secureStorage,
        }) async => client,
      );
      await bootstrap.initialize(secureStorage);
      final service = SupabaseAuthService(bootstrap);

      when(
        () => auth.signInWithPassword(
          email: 'pending@shop.com',
          password: 'password1',
        ),
      ).thenThrow(
        const sb.AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      );
      final unverified = await service.signInWithPassword(
        email: 'pending@shop.com',
        password: 'password1',
      );
      expect(
        unverified,
        const AuthUser(id: '', email: 'pending@shop.com', emailVerified: false),
      );

      when(
        () => auth.signInWithPassword(
          email: 'pending@shop.com',
          password: 'wrong-password',
        ),
      ).thenThrow(
        const sb.AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      await expectLater(
        () => service.signInWithPassword(
          email: 'pending@shop.com',
          password: 'wrong-password',
        ),
        throwsA(isA<sb.AuthApiException>()),
      );
    });
  });

  group('AuthSessionRepositoryImpl', () {
    late AppDatabase database;
    late FakeAuthService authService;
    late LedgerOwnerStorage ownerStorage;
    late List<String> logOutput;
    late AuthErrorMapper errorMapper;
    late AuthSessionRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      authService = FakeAuthService();
      ownerStorage = LedgerOwnerStorage(secureStorage);
      logOutput = <String>[];
      final logger = AppLogger(
        output: logOutput.add,
        enableCrashReporting: false,
      );
      errorMapper = AuthErrorMapper(ErrorHandler(logger));
      repository = AuthSessionRepositoryImpl(
        authService,
        ownerStorage,
        database.customerDao.hasAnyCustomers,
        errorMapper,
      );
    });

    tearDown(() => database.close());

    test('evaluates ledger link status from LedgerOwnerStorage', () async {
      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => null);
      expect(
        await repository.getLedgerLinkStatus('user-a'),
        const Right<AppFailure, LedgerLinkStatus>(LedgerLinkStatus.unlinked),
      );

      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => 'user-a');
      expect(
        await repository.getLedgerLinkStatus('user-a'),
        const Right<AppFailure, LedgerLinkStatus>(
          LedgerLinkStatus.linkedToCurrentUser,
        ),
      );
      expect(
        await repository.getLedgerLinkStatus('user-b'),
        const Right<AppFailure, LedgerLinkStatus>(
          LedgerLinkStatus.linkedToOtherUser,
        ),
      );
    });

    test('reports retained local ledger data including archived customers and audit history', () async {
      expect(
        await repository.hasLocalLedgerData(),
        const Right<AppFailure, bool>(false),
      );

      final customer = await database.customerDao.createCustomer(name: 'Ahmed');
      final tx = await database.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 5000,
      );
      await database.transactionDao.editTransaction(
        id: tx.id,
        type: TransactionTypes.credit,
        amountPiasters: 7500,
        transactionDate: tx.transactionDate,
      );
      expect(await database.transactionDao.getAuditLogs(tx.id), isNotEmpty);

      await database.customerDao.softDeleteCustomer(customer.id);
      expect(
        await repository.hasLocalLedgerData(),
        const Right<AppFailure, bool>(true),
      );
    });

    test('maps session-stream errors to privacy-safe AuthSessionFailure and keeps listening', () async {
      const sensitiveText = 'secret-token-eyJ-owner@shop.com';
      final controller = StreamController<AuthSessionEvent>();
      authService.authStream = controller.stream;

      final emitted = <AuthSessionEvent>[];
      final rawErrors = <Object>[];
      final sub = repository.watchAuthChanges().listen(
        emitted.add,
        onError: rawErrors.add,
      );

      controller.addError(
        sb.AuthRetryableFetchException(
          message: 'Refresh failed for $sensitiveText',
        ),
      );
      controller.addError(
        const sb.AuthException(
          'Callback failed for $sensitiveText',
          code: 'otp_expired',
        ),
      );
      const recoveredUser = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop',
        emailVerified: true,
      );
      controller.add(const AuthSessionSignedIn(recoveredUser));
      await controller.close();
      await sub.asFuture<void>();

      expect(rawErrors, isEmpty);
      expect(emitted, const [
        AuthSessionFailure(AppFailure(AppErrorCode.network)),
        AuthSessionFailure(AppFailure(AppErrorCode.auth)),
        AuthSessionSignedIn(recoveredUser),
      ]);
      for (final entry in logOutput) {
        expect(entry, isNot(contains(sensitiveText)));
      }
    });

    test('maps sign-out unexpected error without logging PII', () async {
      const secretEmail = 'sensitive.owner@example.com';
      authService.errorToThrow = StateError(
        'raw token eyJ.secret.$secretEmail',
      );
      expect(
        await repository.signOut(),
        const Left<AppFailure, void>(AppFailure(AppErrorCode.unexpected)),
      );
      for (final entry in logOutput) {
        expect(entry, isNot(contains(secretEmail)));
        expect(entry, isNot(contains('eyJ')));
      }
      expect(logOutput, [AppErrorCode.unexpected.code]);
    });

    test('aborts first owner write when session ends or switches while owner read is pending', () async {
      const userA = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop A',
        emailVerified: true,
      );
      const userB = AuthUser(
        id: 'user-b',
        email: 'other@shop.com',
        shopName: 'Shop B',
        emailVerified: true,
      );

      for (final replacement in <AuthUser?>[null, userB]) {
        authService.currentUser = userA;
        final readStarted = Completer<void>();
        final releaseRead = Completer<String?>();
        var writeCalls = 0;

        when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
            .thenAnswer((_) {
              if (!readStarted.isCompleted) readStarted.complete();
              return releaseRead.future;
            });
        when(
          () => secureStorage.write(
            key: LedgerOwnerStorage.ownerKey,
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {
          writeCalls++;
        });

        final confirmation = ConfirmLedgerLinkUseCase(repository)(
          user: userA,
          confirmed: true,
        );
        await readStarted.future;

        authService.currentUser = replacement;
        releaseRead.complete(null);

        final result = await confirmation;
        expect(
          result,
          const Left<AppFailure, AuthOutcome?>(AppFailure(AppErrorCode.auth)),
        );
        expect(writeCalls, 0);
      }
    });

    test('does not report A signed in when session changes while an already-started write is pending', () async {
      const userA = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop A',
        emailVerified: true,
      );
      const userB = AuthUser(
        id: 'user-b',
        email: 'other@shop.com',
        shopName: 'Shop B',
        emailVerified: true,
      );

      authService.currentUser = userA;
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();

      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: LedgerOwnerStorage.ownerKey,
          value: userA.id,
        ),
      ).thenAnswer((_) {
        if (!writeStarted.isCompleted) writeStarted.complete();
        return releaseWrite.future;
      });

      final confirmation = ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: true,
      );
      await writeStarted.future;

      authService.currentUser = userB;
      releaseWrite.complete();

      final result = await confirmation;
      expect(
        result,
        const Left<AppFailure, AuthOutcome?>(AppFailure(AppErrorCode.auth)),
      );
    });

    test('aborts first owner write synchronously if session switches after async getCurrentUser resolves', () async {
      const userA = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop A',
        emailVerified: true,
      );
      const userB = AuthUser(
        id: 'user-b',
        email: 'other@shop.com',
        shopName: 'Shop B',
        emailVerified: true,
      );

      authService.currentUser = userA;
      authService.getCurrentUserOverride = () async {
        authService.currentUser = userB;
        return userA;
      };

      var writeCalls = 0;
      when(() => secureStorage.read(key: LedgerOwnerStorage.ownerKey))
          .thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: LedgerOwnerStorage.ownerKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {
        writeCalls++;
      });

      final result = await ConfirmLedgerLinkUseCase(repository)(
        user: userA,
        confirmed: true,
      );

      expect(
        result,
        const Left<AppFailure, AuthOutcome?>(AppFailure(AppErrorCode.auth)),
      );
      expect(writeCalls, 0);
    });

    test('scoped cancellation checks live session synchronously without signing out replacement account', () async {
      const userA = AuthUser(
        id: 'user-a',
        email: 'owner@shop.com',
        shopName: 'Shop A',
        emailVerified: true,
      );
      const userB = AuthUser(
        id: 'user-b',
        email: 'other@shop.com',
        shopName: 'Shop B',
        emailVerified: true,
      );

      final client = MockSupabaseClient();
      final auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);

      final sessionForB = sb.Session(
        accessToken: 'token-b',
        tokenType: 'bearer',
        user: sb.User(
          id: userB.id,
          appMetadata: const {},
          userMetadata: const {'shop_name': 'Shop B'},
          aud: 'authenticated',
          email: userB.email,
          emailConfirmedAt: '2026-01-01T00:00:00Z',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      final sessionForA = sb.Session(
        accessToken: 'token-a',
        tokenType: 'bearer',
        user: sb.User(
          id: userA.id,
          appMetadata: const {},
          userMetadata: const {'shop_name': 'Shop A'},
          aud: 'authenticated',
          email: userA.email,
          emailConfirmedAt: '2026-01-01T00:00:00Z',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );

      final bootstrap = SupabaseBootstrap(
        url: 'https://demo.supabase.co',
        anonKey: 'anon-key',
        initializer: ({
          required url,
          required anonKey,
          required secureStorage,
        }) async => client,
      );
      await bootstrap.initialize(secureStorage);
      final liveRepo = AuthSessionRepositoryImpl(
        SupabaseAuthService(bootstrap),
        ownerStorage,
        database.customerDao.hasAnyCustomers,
        errorMapper,
      );

      when(() => auth.currentSession).thenReturn(sessionForB);
      when(() => auth.signOut(scope: sb.SignOutScope.local))
          .thenAnswer((_) async {});

      final staleCancel = await ConfirmLedgerLinkUseCase(liveRepo)(
        user: userA,
        confirmed: false,
      );
      expect(staleCancel, const Right<AppFailure, AuthOutcome?>(null));
      verifyNever(() => auth.signOut(scope: sb.SignOutScope.local));

      when(() => auth.currentSession).thenReturn(sessionForA);
      final activeCancel = await ConfirmLedgerLinkUseCase(liveRepo)(
        user: userA,
        confirmed: false,
      );
      expect(activeCancel, const Right<AppFailure, AuthOutcome?>(null));
      verify(() => auth.signOut(scope: sb.SignOutScope.local)).called(1);
    });
  });
}
