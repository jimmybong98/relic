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
        _baseUrl = baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5005';

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

  /// Fetch a comprehensive report for a specific OS.
  /// [section] can be `full`, `amostragem` or `liberacao`.
  Future<Map<String, dynamic>?> fetchOsReport(String os,
      {String section = 'full'}) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/reports/os?os=$os&section=$section');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the Excel report for a given OS and type.
  /// Returns `true` if the file was saved successfully.
  Future<bool> exportToExcel({required String os, required String tipo}) async {
    try {
      final uri = Uri.parse('$_baseUrl/reports/export?os=$os&type=$tipo');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final file = File('relatorio_${os}_$tipo.xlsx');
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
    } catch (_) {
      // Ignore errors
    }
    return false;
  }
}
