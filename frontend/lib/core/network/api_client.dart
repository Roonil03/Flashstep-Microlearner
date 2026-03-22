import '../config/api_config.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: '',
            );

  ApiClient._withDefault() : baseUrl = ApiConfig.baseUrl;

  /// Factory that returns an ApiClient using the runtime `ApiConfig.baseUrl`
  factory ApiClient.withConfig() => ApiClient._withDefault();

  Uri uri(String path) {
    final resolved = baseUrl.isNotEmpty ? baseUrl : ApiConfig.baseUrl;
    return Uri.parse('$resolved$path');
  }
}