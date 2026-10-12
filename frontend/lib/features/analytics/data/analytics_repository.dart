import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/analytics_models.dart';
import '../../decks/data/data_sync_service.dart';
import '../../review/data/review_repository.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/network/providers.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    storage: ref.watch(sessionStorageProvider),
    apiClient: ApiClient.withConfig(),
  );
});

final analyticsDashboardProvider = FutureProvider.autoDispose.family<
  AnalyticsDashboardData,
  int
>((ref, rangeDays) async {
  final sync = ref.watch(deckSyncServiceProvider);
  final database = ref.watch(appDatabaseProvider);
  final repository = ref.watch(analyticsRepositoryProvider);
  final reviews = ref.watch(reviewRepositoryProvider);
  // A call can join an earlier automatic sync whose queue snapshot predates
  // the last review. Drain the completed session's remaining operations too.
  for (var attempt = 0; attempt < 2; attempt++) {
    final result = await sync.syncNow();
    if (!result.success)
      throw AnalyticsLoadException(
        result.message,
        isOffline: result.statusCode == null,
      );
    final pending =
        await (database.select(database.syncQueueItems)
              ..where((t) => t.synced.equals(false))
              ..limit(1))
            .get();
    if (pending.isEmpty) break;
    if (attempt == 1)
      throw const AnalyticsLoadException(
        'Reviews are still waiting to sync. Please refresh analytics.',
      );
  }
  final counts = await reviews.getDailyCounts();
  return repository.loadDashboard(rangeDays: rangeDays, dailyCounts: counts);
});

class AnalyticsLoadException implements Exception {
  final String message;
  final bool isOffline;

  const AnalyticsLoadException(this.message, {this.isOffline = false});

  @override
  String toString() => message;
}

class AnalyticsRepository {
  final SessionStorage _storage;
  final ApiClient _apiClient;

  AnalyticsRepository({
    required SessionStorage storage,
    required ApiClient apiClient,
  }) : _storage = storage,
       _apiClient = apiClient;

  Future<AnalyticsDashboardData> loadDashboard({
    required int rangeDays,
    ReviewDailyCounts? dailyCounts,
  }) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('You need to be signed in to view analytics.');
    }

    final uri = _apiClient
        .uri(ApiEndpoints.analyticsDashboard)
        .replace(queryParameters: {'range_days': '$rangeDays'});

    late final http.Response response;

    try {
      response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const AnalyticsLoadException(
        'No internet connection. Reconnect and try loading analytics again.',
        isOffline: true,
      );
    } on http.ClientException {
      throw const AnalyticsLoadException(
        'Analytics could not reach the server. Check your network and try again.',
        isOffline: true,
      );
    } on TimeoutException {
      throw const AnalyticsLoadException(
        'Analytics request timed out. Check your connection and try again.',
        isOffline: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnalyticsLoadException(
        'Analytics sync failed (${response.statusCode}). Please try again shortly.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Analytics response was not a JSON object.');
    }

    return AnalyticsDashboardData.fromJson({
      ...decoded,
      if (dailyCounts != null) ...{
        'cards_reviewed_today': dailyCounts.reviewed,
        'cards_available_today': dailyCounts.available,
        'daily_limit_applied': dailyCounts.limited,
      },
    });
  }
}
