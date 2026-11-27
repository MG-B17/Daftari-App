import 'package:connectivity_plus/connectivity_plus.dart';

import '../../errors/app_exception.dart';

/// Reports available network interfaces, not guaranteed internet reachability.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    try {
      return _hasConnection(await _connectivity.checkConnectivity());
    } catch (_) {
      throw const NetworkException();
    }
  }

  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map(_hasConnection)
      .distinct()
      .handleError((Object error, StackTrace stackTrace) {
        throw const NetworkException();
      });

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
