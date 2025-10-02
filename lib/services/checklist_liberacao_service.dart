import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChecklistLiberacaoService {
  ChecklistLiberacaoService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

  final http.Client _client;
  final String _baseUrl;

  Future<void> registrarChecklist({
    required String re,
    required String grupoMaquina,
    required String maquina,
    required List<Map<String, dynamic>> respostas,
  }) async {
    final uri = Uri.parse('$_baseUrl/checklist/liberacao');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        're': re,
        'grupo_maquina': grupoMaquina,
        'maquina': maquina,
        'respostas': respostas,
      }),
    );

    if (resp.statusCode != 200) {
      var message = 'Falha ao registrar checklist';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {
        // Ignora erros de parse e mantém a mensagem padrão.
      }
      throw Exception(message);
    }
  }
}
