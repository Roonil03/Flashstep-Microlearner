class ApiConfig {
  static String host = '192.168.240.1';
  static int port = 8080;

  static String apiPrefix = '/api/v1';

  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
