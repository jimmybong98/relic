import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';
import '../../../features/operador/data/models.dart';
import 'package:intl/intl.dart';

/// Displays a line chart showing the progression of operator samplings.
/// The user must provide an OS number to fetch the report. End-of-shift
/// and OS closing events are highlighted in the chart.
class OperatorReportChart extends StatefulWidget {
  const OperatorReportChart({super.key});

  @override
  State<OperatorReportChart> createState() => _OperatorReportChartState();
}

class _OperatorReportChartState extends State<OperatorReportChart> {
  final _osCtrl = TextEditingController();
  Future<List<Report>>? _future;

  @override
  void dispose() {
    _osCtrl.dispose();
    super.dispose();
  }

  void _fetch() {
    final os = _osCtrl.text.trim();
    if (os.isEmpty) return;
    final service = ReportService();
    setState(() {
      _future = service.fetchOperatorReleasesByOs(os);
    });
  }

  double _statusToValue(String status) {
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

  Color _statusColor(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return Colors.green.shade600;
      case StatusMedida.reprovadaAbaixo:
        return Colors.red.shade400;
      case StatusMedida.reprovadaAcima:
        return Colors.red.shade400;
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return Colors.amber.shade700;
      case StatusMedida.pendente:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progresso das Amostragens',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: defaultPadding),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;
              final inputField = TextField(
                controller: _osCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número da OS',
                  border: OutlineInputBorder(),
                ),
              );
              final button = ElevatedButton(
                onPressed: _fetch,
                child: const Text('Buscar'),
              );
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    inputField,
                    const SizedBox(height: defaultPadding),
                    Align(alignment: Alignment.centerRight, child: button),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: inputField),
                  const SizedBox(width: defaultPadding),
                  button,
                ],
              );
            },
          ),
          const SizedBox(height: defaultPadding),
          FutureBuilder<List<Report>>(
            future: _future,
            builder: (context, snapshot) {
              if (_future == null) {
                return const Text(
                  'Informe o número da OS para visualizar o gráfico.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Text('Nenhum dado encontrado para a OS.');
              }

              final grouped = <int, List<Report>>{};
              for (final r in data) {
                if (r.idxMedida == null) continue;
                grouped.putIfAbsent(r.idxMedida!, () => []).add(r);
              }
              if (grouped.isEmpty) {
                return const Text('Nenhum dado encontrado para a OS.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  final reports = entry.value
                    ..sort(
                      (a, b) => (DateTime.tryParse(a.createdAt) ?? DateTime(0))
                          .compareTo(
                            DateTime.tryParse(b.createdAt) ?? DateTime(0),
                          ),
                    );
                  final spots = <FlSpot>[];
                  final verticalLines = <VerticalLine>[];
                  for (var i = 0; i < reports.length; i++) {
                    final r = reports[i];
                    final status = r.status.toLowerCase();
                    spots.add(FlSpot(i.toDouble(), _statusToValue(status)));
                    if (status.contains('fim') && status.contains('jornada')) {
                      verticalLines.add(
                        VerticalLine(
                          x: i.toDouble(),
                          color: Colors.orange,
                          strokeWidth: 2,
                        ),
                      );
                    } else if (status.contains('encerrar') ||
                        status.contains('encerramento')) {
                      verticalLines.add(
                        VerticalLine(
                          x: i.toDouble(),
                          color: Colors.red,
                          strokeWidth: 2,
                        ),
                      );
                    }
                  }

                  final first = reports.first;
                  final title = first.titulo.isNotEmpty
                      ? first.titulo
                      : 'Medida ${entry.key}';
                  final faixa = first.faixaTexto.isNotEmpty
                      ? first.faixaTexto
                      : 'faixa_texto ${entry.key}';
                  final label = faixa.isNotEmpty ? '$title - $faixa' : title;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: LineChart(
                            LineChartData(
                              minY: -2,
                              maxY: 2,
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final report = reports[spot.x.toInt()];
                                      final dt = DateTime.tryParse(
                                        report.createdAt,
                                      );
                                      final label = dt != null
                                          ? DateFormat.Hm().format(dt.toLocal())
                                          : report.createdAt;
                                      return LineTooltipItem(
                                        label,
                                        const TextStyle(color: Colors.white),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 72,
                                    getTitlesWidget: (value, meta) {
                                      late final StatusMedida st;
                                      late final String text;
                                      switch (value.toInt()) {
                                        case -2:
                                          st = StatusMedida.reprovadaAbaixo;
                                          text = 'Repr. -';
                                          break;
                                        case -1:
                                          st = StatusMedida.alertaAbaixo;
                                          text = 'Alerta -';
                                          break;
                                        case 0:
                                          st = StatusMedida.ok;
                                          text = 'OK';
                                          break;
                                        case 1:
                                          st = StatusMedida.alertaAcima;
                                          text = 'Alerta +';
                                          break;
                                        case 2:
                                          st = StatusMedida.reprovadaAcima;
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
                                              color: _statusColor(st),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(text),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: false,
                                  barWidth: 3,
                                  color: Colors.blue,
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                              extraLinesData: ExtraLinesData(
                                verticalLines: verticalLines,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
