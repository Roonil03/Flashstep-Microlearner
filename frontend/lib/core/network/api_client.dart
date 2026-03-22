class ApiClient {
  final String baseUrl;

  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.86.4.177:8080',
            );

  Uri uri(String path) => Uri.parse('$baseUrl$path');
}