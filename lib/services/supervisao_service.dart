import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:admin/utils/string_utils.dart';

class SupervisaoService {
  SupervisaoService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

  final http.Client _client;
  final String _baseUrl;

  Future<List<String>> fetchCampos(String tabela) async {
    final uri = Uri.parse('$_baseUrl/supervisor/campos?tabela=$tabela');
    final resp = await _client.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchRegistros(
      String tabela, String part, String op) async {
    final uri = Uri.parse(
        '$_baseUrl/supervisor/registros?tabela=$tabela&partnumber=${normalizeCode(part)}&operacao=${normalizeCode(op)}');
    final resp = await _client.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> inserir(String tabela, Map<String, dynamic> dados) async {
    final uri = Uri.parse('$_baseUrl/supervisor/registros?tabela=$tabela');
    final map = Map<String, dynamic>.from(dados);
    if (map.containsKey('partnumber')) {
      map['partnumber'] = normalizeCode(map['partnumber'].toString());
    }
    if (map.containsKey('operacao')) {
      map['operacao'] = normalizeCode(map['operacao'].toString());
    }
    final resp = await _client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(map));
    return resp.statusCode == 200;
  }

  Future<bool> atualizar(String tabela, Map<String, dynamic> dados) async {
    final uri = Uri.parse('$_baseUrl/supervisor/registros?tabela=$tabela');
    final map = Map<String, dynamic>.from(dados);
    if (map.containsKey('partnumber')) {
      map['partnumber'] = normalizeCode(map['partnumber'].toString());
    }
    if (map.containsKey('operacao')) {
      map['operacao'] = normalizeCode(map['operacao'].toString());
    }
    final resp = await _client.put(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(map));
    return resp.statusCode == 200;
  }
}
