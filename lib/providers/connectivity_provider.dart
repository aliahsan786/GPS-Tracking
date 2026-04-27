import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Thin ChangeNotifier wrapper around [ConnectivityService].
///
/// Providers and widgets consume `online` instead of subscribing to the
/// service directly, so they can rebuild via Provider's existing
/// listener plumbing rather than managing their own stream
/// subscriptions.
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;
  bool _online = true;
  StreamSubscription<bool>? _sub;

  ConnectivityProvider(this._service) {
    _init();
  }

  bool get online => _online;

  Future<void> _init() async {
    _online = await _service.isOnline();
    notifyListeners();
    _sub = _service.onlineStream.listen(_set);
  }

  void _set(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
