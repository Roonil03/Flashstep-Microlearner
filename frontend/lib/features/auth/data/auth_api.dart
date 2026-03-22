import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';

class AuthSession {
  final String token;
  final String userId;
  final String email;
  final String username;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.username,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String nestedUsername = '';
    String nestedUserId = '';
    String nestedEmail = '';
    if (user is Map<String, dynamic>) {
      nestedUsername = user['username'] as String? ?? '';
      nestedUserId = user['userId'] as String? ?? user['id'] as String? ?? '';
      nestedEmail = user['email'] as String? ?? '';
    }
    return AuthSession(
      token: json['token'] as String? ?? '',
      userId: json['userId'] as String? ??
          json['user_id'] as String? ??
          nestedUserId,
      email: json['email'] as String? ?? nestedEmail,
      username: json['username'] as String? ?? nestedUsername,
    );
  }
}

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _client.uri('/auth/register'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Register failed: ${response.body}');
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _client.uri('/auth/login'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected login response');
    }
    return AuthSession.fromJson(decoded);
  }

  Future<bool> validateToken(String token) async {
    final response = await http.get(
      _client.uri('/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<AuthSession> getMe(String token) async {
    final response = await http.get(
      _client.uri('/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch user: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }
    return AuthSession.fromJson(decoded);
  }
}