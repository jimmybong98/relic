import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/machine.dart';

class MachineService {
  MachineService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

  final http.Client _client;
  final String _baseUrl;

  Future<List<Machine>> fetchMaquinas() async {
    final uri = Uri.parse('$_baseUrl/machines');
    final resp = await _client.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      return data
          .map((e) => Machine.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Falha ao carregar máquinas');
  }

  Future<bool> addMaquina(String codigo, String categoria) async {
    final uri = Uri.parse('$_baseUrl/machines');
    final resp = await _client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo, 'categoria': categoria}));
    return resp.statusCode == 200;
  }
}
