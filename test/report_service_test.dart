import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:admin/services/report_service.dart';

void main() {
  test('fetchPreparerReleases hits preparador endpoint', () async {
    late Uri requestedUri;
    final client = MockClient((req) async {
      requestedUri = req.url;
      return http.Response('[]', 200);
    });
    final service = ReportService(client: client, baseUrl: 'http://dummy');
    await service.fetchPreparerReleases();
    expect(requestedUri.path, '/reports/preparador');
  });

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

  test(
    'fetchReleases builds params for preparador partnumber search',
    () async {
      late Uri requestedUri;
      final client = MockClient((req) async {
        requestedUri = req.url;
        return http.Response('[]', 200);
      });
      final service = ReportService(client: client, baseUrl: 'http://dummy');
      await service.fetchReleases(
        tipo: 'preparador',
        partnumber: '0001',
        operacao: '0002',
      );
      expect(requestedUri.path, '/reports/preparador');
      expect(requestedUri.queryParameters['partnumber'], '1');
      expect(requestedUri.queryParameters['operacao'], '2');
    },
  );

  test('fetchOsReport normalizes OS and forwards section parameter', () async {
    late Uri requestedUri;
    final client = MockClient((req) async {
      requestedUri = req.url;
      return http.Response('{"liberacao": []}', 200);
    });
    final service = ReportService(client: client, baseUrl: 'http://dummy');
    await service.fetchOsReport('000456', section: 'liberacao');
    expect(requestedUri.path, '/reports/os');
    expect(requestedUri.queryParameters['section'], 'liberacao');
    expect(requestedUri.queryParameters['os'], '456');
  });
}
