import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/report.dart';
import '../utils/string_utils.dart';

/// Service responsible for fetching reports from the backend API.
class ReportService {
  ReportService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5005';

  final http.Client _client;
  final String _baseUrl;

  /// Fetches the list of reports from `/reports` endpoint.
  Future<List<Report>> fetchReports() async {
    try {
      final uri = Uri.parse('$_baseUrl/reports');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return Report.listFromResponse(response.body);
      }
    } catch (_) {
      // Ignore errors and return empty list
    }
    return [];
  }

  /// Fetch releases performed by preparers.
  Future<List<Report>> fetchPreparerReleases() async {
    try {
      final uri = Uri.parse('$_baseUrl/reports/preparador');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return Report.listFromResponse(response.body);
      }
    } catch (_) {}
    return [];
  }

  /// Fetch releases performed by operators.
  Future<List<Report>> fetchOperatorReleases() async {
    try {
      final uri = Uri.parse('$_baseUrl/reports/operador');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return Report.listFromResponse(response.body);
      }
    } catch (_) {}
    return [];
  }

  /// Fetch releases performed by operators for a specific OS.
  Future<List<Report>> fetchOperatorReleasesByOs(String os) async {
    try {
      final normalized = normalizeCode(os);
      final uri = Uri.parse(_baseUrl)
          .resolve('reports/operador')
          .replace(queryParameters: {'os': normalized});
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return Report.listFromResponse(response.body);
      }
    } catch (_) {}
    return [];
  }

  /// Generic search for releases filtering by [tipo] ("operador" or
  /// "preparador"). The caller can provide either [os] or a combination of
  /// [partnumber] and [operacao] to filter the results. The returned list
  /// contains raw maps so that callers can display arbitrary fields.
  Future<List<Map<String, dynamic>>> fetchReleases({
    required String tipo,
    String? os,
    String? partnumber,
    String? operacao,
  }) async {
    try {
      final endpoint = tipo.toLowerCase() == 'preparador'
          ? 'preparador'
          : 'operador';
      final params = <String, String>{};
      if (os != null && os.isNotEmpty) {
        params['os'] = normalizeCode(os);
      } else if (partnumber != null &&
          operacao != null &&
          partnumber.isNotEmpty &&
          operacao.isNotEmpty) {
        params['partnumber'] = normalizeCode(partnumber);
        params['operacao'] = normalizeCode(operacao);
      }
      final uri = Uri.parse(
        _baseUrl,
      ).resolve('reports/$endpoint').replace(queryParameters: params);
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList(growable: false);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch a comprehensive report for a specific OS.
  /// [section] can be `full`, `amostragem`, `liberacao` or `finalizacao`.
  Future<Map<String, dynamic>?> fetchOsReport(
      String os, {
        String section = 'full',
      }) async {
    try {
      final normalized = normalizeCode(os);
      final uri = Uri.parse(_baseUrl)
          .resolve('reports/os')
          .replace(queryParameters: {'os': normalized, 'section': section});
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch an overview listing all OS with their status and sampling counts.
  Future<List<Map<String, dynamic>>> fetchOsStatusOverview() async {
    try {
      final uri = Uri.parse(_baseUrl).resolve('reports/os_status');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList(growable: false);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Downloads the Excel report for a given OS and type.
  /// Returns `true` if the file was saved successfully.
  Future<bool> exportToExcel({required String os, required String tipo}) async {
    try {
      final normalized = normalizeCode(os);
      final uri = Uri.parse(_baseUrl)
          .resolve('reports/export')
          .replace(queryParameters: {'os': normalized, 'type': tipo});
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final file = File('relatorio_${normalized}_$tipo.xlsx');
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (_) {
      // Ignore errors
    }
    return false;
  }
}