import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _defaultApiBaseUrl = 'http://192.168.0.241:5005';

String resolveApiBaseUrl() {
  final raw = dotenv.env['API_BASE_URL'];
  String candidate;
  if (raw == null || raw.trim().isEmpty) {
    candidate = _defaultApiBaseUrl;
  } else {
    candidate = raw.trim();
  }

  final hasScheme =
      candidate.startsWith('http://') || candidate.startsWith('https://');
  if (!hasScheme) {
    candidate = 'http://$candidate';
  }
  if (candidate.endsWith('/')) {
    candidate = candidate.substring(0, candidate.length - 1);
  }
  return candidate;
}

Uri buildApiUri(String path, [Map<String, dynamic>? queryParameters]) {
  final base = resolveApiBaseUrl();
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final root = Uri.parse(base);
  Map<String, String>? normalizedQuery;
  if (queryParameters != null && queryParameters.isNotEmpty) {
    normalizedQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) return;
      normalizedQuery![key] = value.toString();
    });
    if (normalizedQuery.isEmpty) {
      normalizedQuery = null;
    }
  }

  return Uri(
    scheme: root.scheme.isNotEmpty ? root.scheme : 'http',
    host: root.host,
    port: root.hasPort ? root.port : null,
    path: normalizedPath,
    queryParameters: normalizedQuery,
  );
}
