import 'dart:convert';

/// Simple model representing a report record returned from the backend.
class Report {
  final String os;
  final String partnumber;
  final String operacao;
  final String status;
  final String createdAt;

  /// Friendly text describing the allowed measurement range.
  final String faixaTexto;

  /// Registration number (RE) of the preparer who handled this report.
  final String rePreparador;

  /// Registration number (RE) of the operator who handled this report.
  final String reOperador;

  /// Measurement index when the report represents a specific measure.
  final int? idxMedida;

  /// Measurement title associated with [idxMedida].
  final String titulo;

  Report({
    required this.os,
    required this.partnumber,
    required this.operacao,
    required this.status,
    required this.createdAt,
    this.faixaTexto = '',
    this.rePreparador = '',
    this.reOperador = '',
    this.idxMedida,
    this.titulo = '',
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      os: json['os']?.toString() ?? '',
      partnumber: json['partnumber']?.toString() ?? '',
      operacao: json['operacao']?.toString() ?? '',
      status: (json['status_geral'] ?? json['status'])?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      faixaTexto: (json['faixa_texto'] ?? json['faixaTexto'])?.toString() ?? '',
      rePreparador: json['re_preparador']?.toString() ?? '',
      reOperador: json['re_operador']?.toString() ?? '',
      idxMedida: json['idx_medida'] != null
          ? int.tryParse(json['idx_medida'].toString())
          : null,
      titulo: json['titulo']?.toString() ?? '',
    );
  }

  static List<Report> listFromResponse(String body) {
    final List<dynamic> data = jsonDecode(body) as List<dynamic>;
    return data.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();
  }
}
