import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Minimal connectivity tracker. Exposes a synchronous [isOnline] flag plus a
/// broadcast stream so UI and AI services can react to network changes.
///
/// Note: connectivity_plus reports *interface* availability, not true internet
/// reachability. That is acceptable here — the AI layer treats any provider
/// error with a clear message anyway.
class ConnectivityService {
  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onChange => _controller.stream;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _update(result);
    } catch (_) {
      _isOnline = true; // Assume online rather than blocking the app.
    }
    _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  void dispose() => _controller.close();
}
