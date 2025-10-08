import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../screens/dashboard/components/operator_chart_data.dart';
import '../../../screens/main/components/side_menu.dart';
import '../../../services/report_service.dart';
import '../../../widgets/window_bar.dart';

class OperatorReportComparisonPage extends StatefulWidget {
  const OperatorReportComparisonPage({super.key});

  @override
  State<OperatorReportComparisonPage> createState() =>
      _OperatorReportComparisonPageState();
}

class _OperatorReportComparisonPageState
    extends State<OperatorReportComparisonPage> {
  final _osController = TextEditingController();
  final ReportService _service = ReportService();
  final List<_ComparisonEntry> _entries = <_ComparisonEntry>[];

  bool _loading = false;

  @override
  void dispose() {
    _osController.dispose();
    super.dispose();
  }

  String? get _currentPartnumber =>
      _entries.isEmpty ? null : _entries.first.partnumber;
  String? get _currentOperacao =>
      _entries.isEmpty ? null : _entries.first.operacao;

  Future<void> _addOs() async {
    final os = _osController.text.trim();
    if (os.isEmpty || _loading) return;
    if (_entries.any((entry) => entry.os == os)) {
      _showSnack('A O.S. $os já foi adicionada.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final data = await _service.fetchOperatorReleasesByOs(os);
      if (!mounted) return;
      if (data.isEmpty) {
        _showSnack('Nenhum dado encontrado para a O.S. $os.');
        return;
      }

      final partnumber =
          data.firstWhereOrNull((r) => r.partnumber.isNotEmpty)?.partnumber ??
              data.first.partnumber;
      final operacao =
          data.firstWhereOrNull((r) => r.operacao.isNotEmpty)?.operacao ??
              data.first.operacao;

      if (partnumber.isEmpty || operacao.isEmpty) {
        _showSnack(
          'Não foi possível identificar partnumber/operacao da O.S. $os.',
        );
        return;
      }

      final expectedPart = _currentPartnumber;
      final expectedOp = _currentOperacao;
      if (expectedPart != null &&
          expectedOp != null &&
          (expectedPart != partnumber || expectedOp != operacao)) {
        _showSnack(
          'A O.S. $os pertence a outro partnumber/operação e não pode ser comparada.',
        );
        return;
      }

      final color = _pickColor();
      final series = OperatorChartUtils.buildSeries(data, color: color, os: os);
      if (series.isEmpty) {
        _showSnack('A O.S. $os não possui medidas com dados para exibir.');
        return;
      }

      final map = LinkedHashMap<int, OperatorMeasurementSeries>.fromEntries(
        series.map((item) => MapEntry(item.measurementIndex, item)),
      );

      setState(() {
        _entries.add(
          _ComparisonEntry(
            os: os,
            partnumber: partnumber,
            operacao: operacao,
            color: color,
            seriesByMeasurement: map,
          ),
        );
        _osController.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _removeEntry(_ComparisonEntry entry) {
    setState(() {
      _entries.remove(entry);
    });
  }

  Color _pickColor() {
    const palette = <Color>[
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
    ];
    final used = _entries.map((e) => e.color).toSet();
    for (final color in palette) {
      if (!used.contains(color)) return color;
    }
    // Fallback: cycle through palette
    return palette[_entries.length % palette.length];
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final measurementKeys = SplayTreeSet<int>();
    for (final entry in _entries) {
      measurementKeys.addAll(entry.seriesByMeasurement.keys);
    }

    return Scaffold(
      appBar: const WindowBar(
        title: 'Comparar amostragens (Operador)',
        showMenu: true,
      ),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare as curvas de amostragem por O.S.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Adicione O.S. com o mesmo partnumber/operação para visualizar as curvas lado a lado.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 520;
                  final field = SizedBox(
                    width: isCompact ? double.infinity : 280,
                    child: TextField(
                      controller: _osController,
                      decoration: const InputDecoration(
                        labelText: 'Número da O.S.',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addOs(),
                    ),
                  );
                  final button = ElevatedButton.icon(
                    onPressed: _addOs,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar O.S.'),
                  );
                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: button),
                      ],
                    );
                  }
                  return Row(
                    children: [field, const SizedBox(width: 12), button],
                  );
                },
              ),
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              if (_entries.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Informe pelo menos uma O.S. para iniciar a comparação.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else ...[
                _ComparisonSummary(entries: _entries, onRemove: _removeEntry),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      for (final measurement in measurementKeys)
                        _ComparisonChart(
                          measurement: measurement,
                          series: _entries
                              .map(
                                (entry) =>
                            entry.seriesByMeasurement[measurement],
                          )
                              .whereType<OperatorMeasurementSeries>()
                              .toList(),
                          missingOs: _entries
                              .where(
                                (entry) => !entry.seriesByMeasurement
                                .containsKey(measurement),
                          )
                              .map((entry) => entry.os)
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonEntry {
  _ComparisonEntry({
    required this.os,
    required this.partnumber,
    required this.operacao,
    required this.color,
    required this.seriesByMeasurement,
  });

  final String os;
  final String partnumber;
  final String operacao;
  final Color color;
  final LinkedHashMap<int, OperatorMeasurementSeries> seriesByMeasurement;
}

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({required this.entries, required this.onRemove});

  final List<_ComparisonEntry> entries;
  final ValueChanged<_ComparisonEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    final partnumber = entries.first.partnumber;
    final operacao = entries.first.operacao;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partnumber: $partnumber | Operação: $operacao',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in entries)
                  InputChip(
                    backgroundColor: entry.color.withValues(alpha: 0.15),
                    avatar: CircleAvatar(
                      backgroundColor: entry.color,
                      radius: 5,
                    ),
                    label: Text('O.S. ${entry.os}'),
                    onDeleted: () => onRemove(entry),
                    deleteIcon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  const _ComparisonChart({
    required this.measurement,
    required this.series,
    required this.missingOs,
  });

  final int measurement;
  final List<OperatorMeasurementSeries> series;
  final List<String> missingOs;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = series.first.label;
    final missing = List<String>.from(missingOs);

    final bars = <LineChartBarData>[];
    final tooltips = <LineChartBarData, OperatorMeasurementSeries>{};
    for (final s in series) {
      if (s.spots.isEmpty) {
        missing.add(s.os);
        continue;
      }
      final bar = LineChartBarData(
        spots: s.spots,
        isCurved: false,
        barWidth: 3,
        color: s.color,
        dotData: FlDotData(show: true),
      );
      bars.add(bar);
      tooltips[bar] = s;
    }

    if (bars.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxLength = bars
        .map((bar) => bar.spots.isNotEmpty ? bar.spots.last.x : 0.0)
        .fold<double>(0, (prev, current) => current > prev ? current : prev);

    final verticalLines = series.expand((s) => s.verticalLines).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: -2,
                    maxY: 2,
                    minX: 0,
                    maxX: maxLength,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots
                              .map((spot) {
                            final bar = bars[spot.barIndex];
                            final currentSeries = tooltips[bar];
                            if (currentSeries == null) {
                              return null;
                            }
                            final index = spot.x.round().clamp(
                              0,
                              currentSeries.reports.length - 1,
                            );
                            final label = currentSeries.tooltipLabel(index);
                            return LineTooltipItem(
                              'OS ${currentSeries.os}: $label',
                              TextStyle(color: currentSeries.color),
                            );
                          })
                              .whereType<LineTooltipItem>()
                              .toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 72,
                          getTitlesWidget: (value, meta) =>
                              OperatorChartUtils.buildStatusLegend(value),
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
                    lineBarsData: bars,
                    extraLinesData: ExtraLinesData(
                      verticalLines: verticalLines,
                    ),
                  ),
                ),
              ),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Sem dados para esta medida nas O.S.: ${missing.join(', ')}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}