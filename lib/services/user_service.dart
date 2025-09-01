import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class UserService {
  UserService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

  final http.Client _client;
  final String _baseUrl;

  Map<String, String> _authHeader(String username, String password) {
    final token = base64Encode(utf8.encode('$username:$password'));
    return {
      'Authorization': 'Basic $token',
      'Content-Type': 'application/json'
    };
  }

  Future<List<AppUser>> fetchUsers(String username, String password) async {
    final uri = Uri.parse('$_baseUrl/usuarios');
    final resp = await _client.get(uri, headers: _authHeader(username, password));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar usuários');
    }
    final data = jsonDecode(resp.body) as List;
    return data
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> createUser(String username, String password, bool isAdmin,
      String adminUser, String adminPass) async {
    final uri = Uri.parse('$_baseUrl/usuarios');
    final resp = await _client.post(uri,
        headers: _authHeader(adminUser, adminPass),
        body: jsonEncode({
          'username': username,
          'password': password,
          'is_admin': isAdmin ? 1 : 0
        }));
    return resp.statusCode == 200;
  }
}
