import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';

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
    final st = status.toLowerCase();
    switch (st) {
      case 'pendente':
        return 1;
      case 'reprovado':
      case 'reprovada':
      case 'reprovada acima':
      case 'reprovada_acima':
      case 'reprovada abaixo':
      case 'reprovada_abaixo':
        return 2;
      default:
        if (st.contains('reprovado')) return 2; // covers "aprovado|reprovado"
        return 0; // "ok"/"aprovado" treated as bom
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
          Text('Progresso das Amostragens',
              style: Theme.of(context).textTheme.titleMedium),
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
                    'Informe o número da OS para visualizar o gráfico.');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Text('Nenhum dado encontrado para a OS.');
              }

              final spots = <FlSpot>[];
              final verticalLines = <VerticalLine>[];

              for (var i = 0; i < data.length; i++) {
                final r = data[i];
                final status = r.status.toLowerCase();
                spots.add(FlSpot(i.toDouble(), _statusToValue(status)));
                if (status.contains('fim') && status.contains('jornada')) {
                  verticalLines.add(VerticalLine(
                      x: i.toDouble(),
                      color: Colors.orange,
                      strokeWidth: 2));
                } else if (status.contains('encerrar') ||
                    status.contains('encerramento')) {
                  verticalLines.add(VerticalLine(
                      x: i.toDouble(),
                      color: Colors.red,
                      strokeWidth: 2));
                }
              }

              return SizedBox(
                height: 200,
                width: double.infinity,

                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 2,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text('Boa');
                              case 1:
                                return const Text('Alerta');
                              case 2:
                                return const Text('Reprovada');
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 3,
                        color: Colors.blue,
                        dotData: FlDotData(show: true),
                      )
                    ],
                    extraLinesData: ExtraLinesData(verticalLines: verticalLines),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
