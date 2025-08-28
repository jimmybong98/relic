import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/report.dart';

/// Service responsible for fetching reports from the backend API.
class ReportService {
  ReportService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? (dotenv.env['API_BASE_URL'] ?? '') {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL não configurada no .env e nenhum baseUrl foi passado');
    }
  }

  final http.Client _client;
  final String _baseUrl;

  /// Fetches the list of reports from `/reports` endpoint.
  Future<List<Report>> fetchReports() async {
    final uri = Uri.parse('$_baseUrl/reports');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar relatórios (${response.statusCode}): ${response.body}');
    }
    return Report.listFromResponse(response.body);
  }
}
