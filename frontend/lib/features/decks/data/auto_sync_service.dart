import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_sync_service.dart';

final autoSyncBootstrapProvider = Provider<void>((ref) {
  final service = AutoSyncService(
    syncService: ref.watch(deckSyncServiceProvider),
  );

  ref.onDispose(service.dispose);
  unawaited(service.start());
});

class AutoSyncService {
  final DeckSyncService _syncService;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  bool _syncInFlight = false;
  DateTime? _lastAttemptAt;

  AutoSyncService({
    required DeckSyncService syncService,
    Connectivity? connectivity,
  })  : _syncService = syncService,
        _connectivity = connectivity ?? Connectivity();

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final current = await _connectivity.checkConnectivity();
      await _handleConnectivity(current);
    } catch (_) {
      // Safe to ignore: sync will still be attempted on the next connectivity event.
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      unawaited(_handleConnectivity(results));
    });
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> results) async {
    final hasAnyNetwork =
        results.any((result) => result != ConnectivityResult.none);

    if (!hasAnyNetwork) {
      return;
    }

    final now = DateTime.now();
    if (_syncInFlight) {
      return;
    }

    if (_lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < const Duration(seconds: 4)) {
      return;
    }

    _syncInFlight = true;
    _lastAttemptAt = now;

    try {
      await _syncService.syncNow();
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}