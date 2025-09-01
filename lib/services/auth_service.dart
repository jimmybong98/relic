import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class AuthState {
  const AuthState({required this.username, required this.isAdmin});

  final String username;
  final bool isAdmin;
}

class AuthService extends StateNotifier<AuthState?> {
  AuthService(this._client, this._baseUrl) : super(null);

  final http.Client _client;
  final String _baseUrl;

  Future<bool> login(String username, String password) async {
    final uri = Uri.parse('$_baseUrl/login');
    final resp = await _client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      state = AuthState(
          username: user['username'] as String,
          isAdmin: (user['is_admin'] as int) == 1);
      return true;
    }
    return false;
  }

  void logout() {
    state = null;
  }
}

final authServiceProvider =
    StateNotifierProvider<AuthService, AuthState?>((ref) {
  final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';
  return AuthService(http.Client(), baseUrl);
});
