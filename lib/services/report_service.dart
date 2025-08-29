import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/report.dart';

/// Service responsible for fetching reports from the backend API.
class ReportService {
  ReportService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

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
      final uri = Uri.parse('$_baseUrl/reports/operador?os=$os');
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return Report.listFromResponse(response.body);
      }
    } catch (_) {}
    return [];
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
