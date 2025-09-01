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
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar máquinas');

    }

    final body = jsonDecode(resp.body);
    dynamic raw = body;
    if (body is Map) {
      final candidates = [
        body['machines'],
        body['data'],
        body.values.firstWhere((v) => v is List, orElse: () => null),
      ];
      raw = candidates.firstWhere((v) => v is List, orElse: () => null);
    }

    if (raw is! List) {
      throw Exception('Formato de resposta inválido');
    }

    final list = raw as List;
    return list.where((e) => e != null).map<Machine>((e) {
      if (e is Map) {
        final values = e.values.toList();
        final codigo = e['codigo'] ??
            e['code'] ??
            e['0'] ??
            (values.isNotEmpty ? values[0] : '');
        final categoria = e['categoria'] ??
            e['category'] ??
            e['1'] ??
            (values.length > 1 ? values[1] : '');
        return Machine(
            codigo: codigo.toString(),
            categoria: categoria.toString());
      }
      if (e is List || e is Iterable) {
        final list = e is List ? e : e.toList();
        final categoria = list.isNotEmpty ? list[0].toString() : '';
        final codigo = list.length > 1 ? list[1].toString() : '';
        return Machine(codigo: codigo, categoria: categoria);
      }
      return Machine(codigo: e.toString(), categoria: '');
    }).toList();
  }

  Future<bool> addMaquina(String codigo, String categoria) async {
    final uri = Uri.parse('$_baseUrl/machines');
    final resp = await _client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo, 'categoria': categoria}));
    return resp.statusCode == 200;
  }

  Future<bool> updateMaquina(
      String oldCodigo, String codigo, String categoria) async {
    final uri = Uri.parse('$_baseUrl/machines/$oldCodigo');
    final resp = await _client.put(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo, 'categoria': categoria}));
    return resp.statusCode == 200;
  }
}
