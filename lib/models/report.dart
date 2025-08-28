import 'dart:convert';

/// Simple model representing a report record returned from the backend.
class Report {
  final String os;
  final String partnumber;
  final String operacao;
  final String status;
  final String createdAt;

  Report({
    required this.os,
    required this.partnumber,
    required this.operacao,
    required this.status,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      os: json['os']?.toString() ?? '',
      partnumber: json['partnumber']?.toString() ?? '',
      operacao: json['operacao']?.toString() ?? '',
      status: (json['status'] ?? json['status_geral'])?.toString() ?? '',
      createdAt: (json['created_at'] ?? json['data'] ?? json['timestamp'])
              ?.toString() ??
          '',
    );
  }

  static List<Report> listFromResponse(String body) {
    final dynamic decoded = jsonDecode(body);
    final List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      final key = ['data', 'results', 'rows', 'records']
          .firstWhere((k) => decoded[k] is List, orElse: () => '');
      list = key.isNotEmpty ? List<dynamic>.from(decoded[key] as List) : [];
    } else {
      list = [];
    }
    return list
        .map((e) => Report.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
