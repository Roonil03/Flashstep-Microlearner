class ApiConfig {
  static String host = 'flashstep-api.onrender.com';
  static int port = 8080;

  static String apiPrefix = '/api/v1';

  static String get baseUrl => 'https://$host:$port$apiPrefix';
}
