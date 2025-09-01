import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:admin/services/report_service.dart';

void main() {
  test('normalizes OS parameter before request', () async {
    late Uri requestedUri;
    final client = MockClient((req) async {
      requestedUri = req.url;
      return http.Response('[]', 200);
    });
    final service = ReportService(client: client, baseUrl: 'http://dummy');
    await service.fetchOperatorReleasesByOs('000123');
    expect(requestedUri.path, '/reports/operador');
    expect(requestedUri.queryParameters['os'], '123');
  });
}
