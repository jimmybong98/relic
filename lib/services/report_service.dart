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
}
