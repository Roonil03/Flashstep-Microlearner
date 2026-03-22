class ApiConfig {
  static String host = 'localhost';
  static int port = 8080;

  static String apiPrefix = '/api/v1';

  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
