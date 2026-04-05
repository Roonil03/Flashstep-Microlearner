import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    storage: const SessionStorage(),
    apiClient: ApiClient.withConfig(),
  );
});

final analyticsDashboardProvider =
    FutureProvider.family<AnalyticsDashboardData, int>((ref, rangeDays) async {
  return ref.watch(analyticsRepositoryProvider).loadDashboard(
        rangeDays: rangeDays,
      );
});

class AnalyticsRepository {
  final SessionStorage _storage;
  final ApiClient _apiClient;

  AnalyticsRepository({
    required SessionStorage storage,
    required ApiClient apiClient,
  })  : _storage = storage,
        _apiClient = apiClient;

  Future<AnalyticsDashboardData> loadDashboard({
    required int rangeDays,
  }) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('You need to be signed in to view analytics.');
    }

    final uri = _apiClient.uri(ApiEndpoints.analyticsDashboard).replace(
      queryParameters: {
        'range_days': '$rangeDays',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Analytics request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Analytics response was not a JSON object.');
    }

    return AnalyticsDashboardData.fromJson(decoded);
  }
}
