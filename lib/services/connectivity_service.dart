import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Emits `true` when the device has a usable network, `false` otherwise.
///
/// We collapse connectivity_plus's list-of-results into a single boolean
/// because that's all the UI and sync logic care about. If we ever need
/// "wifi vs mobile" detail we can expose it later.
abstract class ConnectivityService {
  Stream<bool> get onlineStream;
  Future<bool> isOnline();
}

class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity;
  late final StreamController<bool> _controller;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityServiceImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _controller = StreamController<bool>.broadcast(
      onListen: _attach,
      onCancel: _detach,
    );
  }

  void _attach() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isOnline(results));
    });
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  @override
  Stream<bool> get onlineStream => _controller.stream;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }
}
