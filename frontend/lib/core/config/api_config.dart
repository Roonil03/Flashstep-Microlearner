class ApiConfig {
  // Change this single IP/host and port to point the entire frontend to your backend.
  // Example: '10.86.4.177' or '192.168.1.10' or use domain name.
  static String host = '10.86.4.177';
  static int port = 8080;

  // Path prefix for API versioning. Keep empty or use '/api/v1' if backend requires it.
  static String apiPrefix = '/api/v1';

  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
