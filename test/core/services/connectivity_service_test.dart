import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockConnectivity connectivity;
  late ConnectivityService service;
  setUp(() {
    connectivity = MockConnectivity();
    service = ConnectivityService(connectivity);
  });

  test(
    'any active interface means connected, none or empty means offline',
    () async {
      for (final entry in <List<ConnectivityResult>, bool>{
        []: false,
        [ConnectivityResult.none]: false,
        [ConnectivityResult.wifi]: true,
        [ConnectivityResult.mobile, ConnectivityResult.vpn]: true,
        [ConnectivityResult.none, ConnectivityResult.ethernet]: true,
      }.entries) {
        when(() => connectivity.checkConnectivity())
            .thenAnswer((_) async => entry.key);
        expect(await service.isConnected, entry.value);
      }
    },
  );

  test('stream maps and deduplicates boolean status', () async {
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => Stream.fromIterable([
        <ConnectivityResult>[],
        [ConnectivityResult.none],
        [ConnectivityResult.wifi],
        [ConnectivityResult.mobile],
        [ConnectivityResult.none],
      ]),
    );
    await expectLater(
      service.onConnectivityChanged,
      emitsInOrder([false, true, false, emitsDone]),
    );
  });

  test('plugin failures become safe typed errors', () async {
    when(() => connectivity.checkConnectivity())
        .thenThrow(Exception('private details'));
    await expectLater(service.isConnected, throwsA(isA<NetworkException>()));
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => Stream.error(Exception('private details')));
    await expectLater(
      service.onConnectivityChanged,
      emitsError(isA<NetworkException>()),
    );
  });

  test('cancelling downstream releases the platform subscription', () async {
    var cancelled = false;
    final controller = StreamController<List<ConnectivityResult>>(
      onCancel: () => cancelled = true,
    );
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => controller.stream);
    final subscription = service.onConnectivityChanged.listen((_) {});
    await subscription.cancel();
    expect(cancelled, isTrue);
    await controller.close();
  });
}
