class ApiConfig {
  static String host = 'flashstep-api.onrender.com';

  static String apiPrefix = '/api/v1';

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    return (override.isEmpty ? 'https://$host$apiPrefix' : override)
        .replaceFirst(RegExp(r'/+$'), '');
  }
}
