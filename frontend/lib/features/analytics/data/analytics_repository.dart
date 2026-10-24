import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/analytics_cache_store.dart';
import '../../../core/storage/app_database.dart';
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

  // Read the last successful snapshot first. This keeps the analytics screen
  // useful during startup and offline periods while a stale snapshot is
  // refreshed in the background.
  ReviewDailyCounts? localCounts;
  try {
    localCounts = await reviews.getDailyCounts();
  } catch (_) {}
  final cached = await repository.readCachedDashboard(
    rangeDays: rangeDays,
    dailyCounts: localCounts,
  );
  if (cached != null) {
    if (repository.shouldRefresh(cached, dailyCounts: localCounts)) {
      unawaited(
        _fetchFreshAnalytics(
              sync: sync,
              database: database,
              repository: repository,
              reviews: reviews,
              rangeDays: rangeDays,
            )
            .then((_) {
              // The provider will read the just-written cache. If the route is
              // still visible this replaces the stale snapshot without showing a
              // loading skeleton or making the user press Refresh.
              try {
                ref.invalidateSelf();
              } catch (_) {}
            })
            .catchError((_) {}),
      );
    }
    return cached.data;
  }

  return _fetchFreshAnalytics(
    sync: sync,
    database: database,
    repository: repository,
    reviews: reviews,
    rangeDays: rangeDays,
  );
});

Future<AnalyticsDashboardData> _fetchFreshAnalytics({
  required DeckSyncService sync,
  required AppDatabase database,
  required AnalyticsRepository repository,
  required ReviewRepository reviews,
  required int rangeDays,
}) async {
  // A call can join an earlier automatic sync whose queue snapshot predates
  // the last review. Drain the completed session's remaining operations too.
  for (var attempt = 0; attempt < 2; attempt++) {
    final result = await sync.syncNow();
    if (!result.success) {
      throw AnalyticsLoadException(
        result.message,
        isOffline: result.statusCode == null,
      );
    }
    final pending =
        await (database.select(database.syncQueueItems)
              ..where((t) => t.synced.equals(false))
              ..limit(1))
            .get();
    if (pending.isEmpty) break;
    if (attempt == 1) {
      throw const AnalyticsLoadException(
        'Reviews are still waiting to sync. Please refresh analytics.',
      );
    }
  }
  final counts = await reviews.getDailyCounts();
  return repository.fetchDashboard(rangeDays: rangeDays, dailyCounts: counts);
}

class AnalyticsLoadException implements Exception {
  final String message;
  final bool isOffline;

  const AnalyticsLoadException(this.message, {this.isOffline = false});

  @override
  String toString() => message;
}

class AnalyticsCacheSnapshot {
  final AnalyticsDashboardData data;
  final DateTime cachedAt;
  final Map<String, dynamic> rawData;

  const AnalyticsCacheSnapshot({
    required this.data,
    required this.cachedAt,
    required this.rawData,
  });
}

class AnalyticsRepository {
  final SessionStorage _storage;
  final ApiClient _apiClient;
  final AnalyticsCacheStore _cacheStore;
  final Map<String, AnalyticsCacheEntry> _memoryCache = {};
  final Map<String, Future<AnalyticsDashboardData>> _inFlightRefreshes = {};

  static const cacheMaxAge = Duration(minutes: 5);
  // Keep persistent snapshots available for offline use, but retain at most
  // one small snapshot in RAM. Large deck-insight responses are read from disk
  // on demand and are released after the page is disposed.
  static const _maxMemoryCacheEntries = 1;
  static const _maxMemoryCacheBytes = 256 * 1024;

  AnalyticsRepository({
    required SessionStorage storage,
    required ApiClient apiClient,
    AnalyticsCacheStore? cacheStore,
  }) : _storage = storage,
       _apiClient = apiClient,
       _cacheStore = cacheStore ?? AnalyticsCacheStore();

  String _cacheKey(String userId, int rangeDays) => '$userId::$rangeDays';

  Future<String> _requireUserId() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('You need to be signed in to view analytics.');
    }
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('You need to be signed in to view analytics.');
    }
    return userId;
  }

  Future<AnalyticsCacheSnapshot?> readCachedDashboard({
    required int rangeDays,
    ReviewDailyCounts? dailyCounts,
  }) async {
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) return null;
    final key = _cacheKey(userId, rangeDays);
    var entry = _memoryCache[key];
    entry ??= await _cacheStore.read(userId: userId, rangeDays: rangeDays);
    if (entry == null) return null;
    _rememberMemory(key, entry);
    return AnalyticsCacheSnapshot(
      data: _withDailyCounts(entry.data, dailyCounts),
      cachedAt: entry.cachedAt,
      rawData: entry.data,
    );
  }

  bool shouldRefresh(
    AnalyticsCacheSnapshot snapshot, {
    ReviewDailyCounts? dailyCounts,
  }) {
    if (DateTime.now().toUtc().difference(snapshot.cachedAt) >= cacheMaxAge) {
      return true;
    }
    if (dailyCounts == null) return false;
    final cachedReviewed =
        (snapshot.rawData['cards_reviewed_today'] as num?)?.toInt();
    final cachedAvailable =
        (snapshot.rawData['cards_available_today'] as num?)?.toInt();
    return (cachedReviewed != null && cachedReviewed != dailyCounts.reviewed) ||
        (cachedAvailable != null && cachedAvailable != dailyCounts.available);
  }

  Future<void> clearCachedDashboard({required int rangeDays}) async {
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) return;
    _memoryCache.remove(_cacheKey(userId, rangeDays));
    await _cacheStore.delete(userId: userId, rangeDays: rangeDays);
  }

  Future<AnalyticsDashboardData> loadDashboard({
    required int rangeDays,
    ReviewDailyCounts? dailyCounts,
    bool forceRefresh = false,
  }) async {
    final cached = await readCachedDashboard(
      rangeDays: rangeDays,
      dailyCounts: dailyCounts,
    );
    if (cached != null &&
        !forceRefresh &&
        !shouldRefresh(cached, dailyCounts: dailyCounts)) {
      return cached.data;
    }
    return fetchDashboard(rangeDays: rangeDays, dailyCounts: dailyCounts);
  }

  Future<AnalyticsDashboardData> fetchDashboard({
    required int rangeDays,
    ReviewDailyCounts? dailyCounts,
  }) async {
    final userId = await _requireUserId();
    final key = _cacheKey(userId, rangeDays);
    final existing = _inFlightRefreshes[key];
    if (existing != null) return existing;

    final request = _fetchDashboard(
      userId: userId,
      rangeDays: rangeDays,
      dailyCounts: dailyCounts,
    );
    _inFlightRefreshes[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightRefreshes[key], request)) {
        _inFlightRefreshes.remove(key);
      }
    }
  }

  Future<AnalyticsDashboardData> _fetchDashboard({
    required String userId,
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

    final rawData = Map<String, dynamic>.from(decoded);
    final entry = AnalyticsCacheEntry(
      cachedAt: DateTime.now().toUtc(),
      data: rawData,
    );
    _rememberMemory(_cacheKey(userId, rangeDays), entry);
    await _cacheStore.write(
      userId: userId,
      rangeDays: rangeDays,
      data: rawData,
    );
    return _withDailyCounts(rawData, dailyCounts);
  }

  AnalyticsDashboardData _withDailyCounts(
    Map<String, dynamic> data,
    ReviewDailyCounts? dailyCounts,
  ) {
    return AnalyticsDashboardData.fromJson({
      ...data,
      if (dailyCounts != null) ...{
        'cards_reviewed_today': dailyCounts.reviewed,
        'cards_available_today': dailyCounts.available,
        'daily_limit_applied': dailyCounts.limited,
      },
    });
  }

  void _rememberMemory(String key, AnalyticsCacheEntry entry) {
    final encodedBytes = utf8.encode(jsonEncode(entry.data)).length;
    if (encodedBytes > _maxMemoryCacheBytes) {
      _memoryCache.remove(key);
      return;
    }
    if (!_memoryCache.containsKey(key) &&
        _memoryCache.length >= _maxMemoryCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    // Removing and reinserting makes the single retained snapshot the most
    // recently used entry if the limit is increased later.
    _memoryCache.remove(key);
    _memoryCache[key] = entry;
  }
}
