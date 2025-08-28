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
      status: json['status_geral']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  static List<Report> listFromResponse(String body) {
    final List<dynamic> data = jsonDecode(body) as List<dynamic>;
    return data.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();
  }
}
