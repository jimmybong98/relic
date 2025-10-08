import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/report.dart';
import '../../../features/operador/data/models.dart';

/// Helper utilities to prepare chart data for operator sampling charts.
class OperatorChartUtils {
  OperatorChartUtils._();

  /// Maps a status string returned by the API to the numeric value used in the
  /// chart's Y axis.
  static double statusToValue(String status) {
    switch (statusFromString(status)) {
      case StatusMedida.reprovadaAbaixo:
        return -2;
      case StatusMedida.alertaAbaixo:
        return -1;
      case StatusMedida.ok:
      case StatusMedida.pendente:
        return 0;
      case StatusMedida.alertaAcima:
        return 1;
      case StatusMedida.reprovadaAcima:
        return 2;
    }
  }

  /// Returns the color associated with a status.
  static Color statusColor(StatusMedida status) {
    switch (status) {
      case StatusMedida.ok:
        return Colors.green.shade600;
      case StatusMedida.reprovadaAbaixo:
      case StatusMedida.reprovadaAcima:
        return Colors.red.shade400;
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return Colors.amber.shade700;
      case StatusMedida.pendente:
        return Colors.grey;
    }
  }

  /// Builds the legend widget used on the chart's Y axis for the given value.
  static Widget buildStatusLegend(double value) {
    late final StatusMedida status;
    late final String text;
    switch (value.toInt()) {
      case -2:
        status = StatusMedida.reprovadaAbaixo;
        text = 'Repr. -';
        break;
      case -1:
        status = StatusMedida.alertaAbaixo;
        text = 'Alerta -';
        break;
      case 0:
        status = StatusMedida.ok;
        text = 'OK';
        break;
      case 1:
        status = StatusMedida.alertaAcima;
        text = 'Alerta +';
        break;
      case 2:
        status = StatusMedida.reprovadaAcima;
        text = 'Repr. +';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  /// Creates a list of measurement series grouped by [Report.idxMedida].
  static List<OperatorMeasurementSeries> buildSeries(
      List<Report> reports, {
        required Color color,
        required String os,
      }) {
    final grouped = <int, List<Report>>{};
    for (final report in reports) {
      final idx = report.idxMedida;
      if (idx == null) continue;
      grouped.putIfAbsent(idx, () => <Report>[]).add(report);
    }
    final formatter = DateFormat.Hm();
    return grouped.entries.map((entry) {
      final sorted = entry.value
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a.createdAt) ?? DateTime(0);
          final bDate = DateTime.tryParse(b.createdAt) ?? DateTime(0);
          return aDate.compareTo(bDate);
        });
      final spots = <FlSpot>[];
      final verticalLines = <VerticalLine>[];
      for (var i = 0; i < sorted.length; i++) {
        final report = sorted[i];
        final lowered = report.status.toLowerCase();
        spots.add(FlSpot(i.toDouble(), statusToValue(lowered)));
        if (lowered.contains('pausa') && lowered.contains('jornada')) {
          verticalLines.add(
            VerticalLine(x: i.toDouble(), color: Colors.orange, strokeWidth: 2),
          );
        } else if (lowered.contains('fim') && lowered.contains('jornada')) {
          verticalLines.add(
            VerticalLine(x: i.toDouble(), color: Colors.orange, strokeWidth: 2),
          );
        } else if (lowered.contains('encerrar') ||
            lowered.contains('encerramento')) {
          verticalLines.add(
            VerticalLine(x: i.toDouble(), color: Colors.red, strokeWidth: 2),
          );
        }
      }
      final first = sorted.first;
      final title = first.titulo.isNotEmpty
          ? first.titulo
          : 'Medida ${entry.key}';
      final faixa = first.faixaTexto.isNotEmpty
          ? first.faixaTexto
          : 'faixa_texto ${entry.key}';
      final label = faixa.isNotEmpty ? '$title - $faixa' : title;
      return OperatorMeasurementSeries(
        measurementIndex: entry.key,
        label: label,
        os: os,
        reports: List<Report>.unmodifiable(sorted),
        spots: List<FlSpot>.unmodifiable(spots),
        verticalLines: List<VerticalLine>.unmodifiable(verticalLines),
        color: color,
        tooltipFormatter: (report) {
          final dt = DateTime.tryParse(report.createdAt);
          final timeLabel = dt != null
              ? formatter.format(dt.toLocal())
              : report.createdAt;
          final machine = report.maquina.trim();
          if (machine.isEmpty) {
            return timeLabel;
          }
          return '$timeLabel\nMáquina: $machine';
        },
      );
    }).toList();
  }
}

/// Represents a series in the chart for a specific measurement index.
class OperatorMeasurementSeries {
  OperatorMeasurementSeries({
    required this.measurementIndex,
    required this.label,
    required this.os,
    required this.reports,
    required this.spots,
    required this.verticalLines,
    required this.color,
    required String Function(Report report) tooltipFormatter,
  }) : _tooltipFormatter = tooltipFormatter;

  final int measurementIndex;
  final String label;
  final String os;
  final List<Report> reports;
  final List<FlSpot> spots;
  final List<VerticalLine> verticalLines;
  final Color color;
  final String Function(Report report) _tooltipFormatter;

  String tooltipLabel(int index) {
    if (index < 0 || index >= reports.length) return '';
    return _tooltipFormatter(reports[index]);
  }
}