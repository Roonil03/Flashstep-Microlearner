import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncPhase { idle, syncing, success, offline, failed }

class SyncStatus {
  final String? userId;
  final SyncPhase phase;
  final DateTime? lastSuccessfulAt;
  final String? message;

  const SyncStatus({
    this.userId,
    this.phase = SyncPhase.idle,
    this.lastSuccessfulAt,
    this.message,
  });
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>(
      (ref) => SyncStatusNotifier(),
    );

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void start(String userId) {
    if (!mounted) return;
    state = SyncStatus(
      userId: userId,
      phase: SyncPhase.syncing,
      lastSuccessfulAt: state.userId == userId ? state.lastSuccessfulAt : null,
    );
  }

  void finish(
    String userId, {
    required bool success,
    required bool offline,
    required String message,
    DateTime? completedAt,
  }) {
    if (!mounted) return;
    if (state.userId != userId) return;
    state = SyncStatus(
      userId: userId,
      phase:
          success
              ? SyncPhase.success
              : offline
              ? SyncPhase.offline
              : SyncPhase.failed,
      lastSuccessfulAt:
          success
              ? completedAt ?? DateTime.now().toUtc()
              : state.lastSuccessfulAt,
      message: message,
    );
  }

  void offline(String userId) {
    if (!mounted) return;
    state = SyncStatus(
      userId: userId,
      phase: SyncPhase.offline,
      lastSuccessfulAt: state.userId == userId ? state.lastSuccessfulAt : null,
      message: 'No network connection. Changes remain on this device.',
    );
  }
}
