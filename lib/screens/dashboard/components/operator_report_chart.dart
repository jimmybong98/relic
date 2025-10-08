import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';
import 'operator_chart_data.dart';

/// Displays a line chart showing the progression of operator samplings.
/// The user must provide an OS number to fetch the report. End-of-shift
/// and OS closing events are highlighted in the chart.
class OperatorReportChart extends StatefulWidget {
  const OperatorReportChart({super.key, this.backgroundColor});

  final Color? backgroundColor;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? secondaryColor,
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

              final series = OperatorChartUtils.buildSeries(
                data,
                color: Colors.blue,
                os: data.first.os,
              );
              if (series.isEmpty) {
                return const Text('Nenhum dado encontrado para a OS.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: series.map((measurement) {
                  final label = measurement.label;

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
                                      final index = spot.x.round().clamp(
                                        0,
                                        measurement.reports.length - 1,
                                      );
                                      final label = measurement.tooltipLabel(
                                        index,
                                      );
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
                                    getTitlesWidget: (value, meta) =>
                                        OperatorChartUtils.buildStatusLegend(
                                          value,
                                        ),
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
                                  spots: measurement.spots,
                                  isCurved: false,
                                  barWidth: 3,
                                  color: measurement.color,
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                              extraLinesData: ExtraLinesData(
                                verticalLines: measurement.verticalLines,
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
