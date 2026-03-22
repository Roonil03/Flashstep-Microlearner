class ApiConfig {
  // For USB debugging: use localhost with 'adb reverse tcp:8080 tcp:8080'
  // For WiFi: change to your machine's IP (e.g., '192.168.x.x')
  static String host = 'localhost';
  static int port = 8080;

  static String apiPrefix = '/api/v1';

  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
