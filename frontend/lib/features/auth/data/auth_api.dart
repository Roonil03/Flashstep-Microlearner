import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

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

  Map<String, String> _jsonHeaders([String? token]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  String _extractErrorMessage(
    http.Response response, {
    String fallback = 'Request failed',
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {}

    final body = response.body.trim();
    if (body.isNotEmpty) {
      return body;
    }

    return fallback;
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _client.uri(ApiEndpoints.register),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, fallback: 'Register failed'),
      );
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _client.uri(ApiEndpoints.login),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, fallback: 'Login failed'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected login response');
    }

    return AuthSession.fromJson(decoded);
  }

  Future<bool> validateToken(String token) async {
    final response = await http.get(
      _client.uri(ApiEndpoints.me),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<AuthSession> getMe(String token) async {
    final response = await http.get(
      _client.uri(ApiEndpoints.me),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, fallback: 'Failed to fetch user'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    return AuthSession.fromJson(decoded);
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      _client.uri(ApiEndpoints.changePassword),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, fallback: 'Password update failed'),
      );
    }
  }

  Future<void> deleteAccount({
    required String token,
  }) async {
    final response = await http.delete(
      _client.uri(ApiEndpoints.deleteAccount),
      headers: _jsonHeaders(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, fallback: 'Account deletion failed'),
      );
    }
  }
}