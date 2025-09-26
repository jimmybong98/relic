import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:admin/widgets/window_bar.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../services/report_service.dart';

const _todos = '__all__';

const Map<String, String> _headerMap = {
  'os': 'OS',
  'status': 'Status',
  'reprovada_abaixo': 'Reprovada abaixo',
  'alerta_abaixo': 'Alerta abaixo',
  'ok': 'OK',
  'alerta_acima': 'Alerta acima',
  'reprovada_acima': 'Reprovada acima',
  'maquinas': 'Máquinas',
  'categorias': 'Categorias',
  'partnumbers': 'Part numbers',
};

const List<String> _statusKeys = [
  'reprovada_abaixo',
  'alerta_abaixo',
  'ok',
  'alerta_acima',
  'reprovada_acima',
];

/// Page that lists all OS with their general status and sampling counts.
class StatusOsPage extends StatefulWidget {
  const StatusOsPage({super.key});

  @override
  State<StatusOsPage> createState() => _StatusOsPageState();
}

class _StatusOsPageState extends State<StatusOsPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _allRows = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];

  List<String> _categorias = const <String>[];
  List<String> _maquinas = const <String>[];
  List<String> _partnumbers = const <String>[];
  List<String> _osOptions = const <String>[];

  String? _categoriaSelecionada;
  String? _maquinaSelecionada;
  String? _partnumberSelecionado;
  String? _osSelecionada;

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final data = await ReportService().fetchOsStatusOverview();
    if (!mounted) return;
    final parsed = data
        .map<Map<String, dynamic>>((raw) {
          final mapa = Map<String, dynamic>.from(raw);
          for (final key in _statusKeys) {
            final valor = mapa[key];
            if (valor is num) {
              mapa[key] = valor.toInt();
            } else {
              mapa[key] = 0;
            }
          }
          mapa['categorias'] = SplayTreeSet<String>.from(
            (mapa['categorias'] as List?)?.whereType<String>() ??
                const <String>[],
          ).toList(growable: false);
          mapa['maquinas'] = SplayTreeSet<String>.from(
            (mapa['maquinas'] as List?)?.whereType<String>() ??
                const <String>[],
          ).toList(growable: false);
          mapa['partnumbers'] = SplayTreeSet<String>.from(
            (mapa['partnumbers'] as List?)?.whereType<String>() ??
                const <String>[],
          ).toList(growable: false);
          mapa['status'] = (mapa['status'] ?? '').toString();
          mapa['os'] = (mapa['os'] ?? '').toString();
          return mapa;
        })
        .toList(growable: false);

    final categorias = SplayTreeSet<String>();
    final maquinas = SplayTreeSet<String>();
    final partnumbers = SplayTreeSet<String>();
    final ordens = SplayTreeSet<String>();

    for (final row in parsed) {
      categorias.addAll(row['categorias'].cast<String>());
      maquinas.addAll(row['maquinas'].cast<String>());
      partnumbers.addAll(row['partnumbers'].cast<String>());
      ordens.add(row['os'] as String);
    }

    var categoriaSelecionada = _categoriaSelecionada;
    if (categoriaSelecionada != null &&
        !categorias.contains(categoriaSelecionada)) {
      categoriaSelecionada = null;
    }
    var maquinaSelecionada = _maquinaSelecionada;
    if (maquinaSelecionada != null && !maquinas.contains(maquinaSelecionada)) {
      maquinaSelecionada = null;
    }
    var partnumberSelecionado = _partnumberSelecionado;
    if (partnumberSelecionado != null &&
        !partnumbers.contains(partnumberSelecionado)) {
      partnumberSelecionado = null;
    }
    var osSelecionada = _osSelecionada;
    if (osSelecionada != null && !ordens.contains(osSelecionada)) {
      osSelecionada = null;
    }

    final filtrado = _filtrarLista(
      parsed,
      categoria: categoriaSelecionada,
      maquina: maquinaSelecionada,
      partnumber: partnumberSelecionado,
      os: osSelecionada,
    );

    setState(() {
      _allRows = parsed;
      _rows = filtrado;
      _categorias = categorias.toList(growable: false);
      _maquinas = maquinas.toList(growable: false);
      _partnumbers = partnumbers.toList(growable: false);
      _osOptions = ordens.toList(growable: false);
      _categoriaSelecionada = categoriaSelecionada;
      _maquinaSelecionada = maquinaSelecionada;
      _partnumberSelecionado = partnumberSelecionado;
      _osSelecionada = osSelecionada;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _filtrarLista(
    List<Map<String, dynamic>> base, {
    String? categoria,
    String? maquina,
    String? partnumber,
    String? os,
  }) {
    return base
        .where((row) {
          final categorias =
              (row['categorias'] as List?)?.whereType<String>().toList() ??
              const [];
          final maquinas =
              (row['maquinas'] as List?)?.whereType<String>().toList() ??
              const [];
          final partnumbers =
              (row['partnumbers'] as List?)?.whereType<String>().toList() ??
              const [];
          final osValor = row['os']?.toString() ?? '';

          if (categoria != null &&
              categoria.isNotEmpty &&
              !categorias.contains(categoria)) {
            return false;
          }
          if (maquina != null &&
              maquina.isNotEmpty &&
              !maquinas.contains(maquina)) {
            return false;
          }
          if (partnumber != null &&
              partnumber.isNotEmpty &&
              !partnumbers.contains(partnumber)) {
            return false;
          }
          if (os != null && os.isNotEmpty && osValor != os) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _atualizarFiltro(void Function() atualizar) {
    setState(() {
      atualizar();
      _rows = _filtrarLista(
        _allRows,
        categoria: _categoriaSelecionada,
        maquina: _maquinaSelecionada,
        partnumber: _partnumberSelecionado,
        os: _osSelecionada,
      );
    });
  }

  int _contarOsPorStatus(String status) {
    return _rows.where((row) => (row['status'] ?? '') == status).length;
  }

  Map<String, int> _totaisGeraisAmostragens() {
    final totais = {for (final key in _statusKeys) key: 0};
    for (final row in _rows) {
      for (final key in _statusKeys) {
        final valor = row[key];
        if (valor is num) {
          totais[key] = (totais[key] ?? 0) + valor.toInt();
        }
      }
    }
    return totais;
  }

  String _formatarValor(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return '';
    if (value is List) {
      return value.whereType<String>().join(', ');
    }
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  Widget _buildDropdown({
    required String label,
    required List<String> opcoes,
    required String? valor,
    required ValueChanged<String?> onChanged,
  }) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: _todos, child: Text('Todos')),
      ...opcoes.map(
        (opcao) => DropdownMenuItem<String>(value: opcao, child: Text(opcao)),
      ),
    ];

    return DropdownButtonFormField<String>(
      value: valor ?? _todos,
      items: items,
      decoration: InputDecoration(labelText: label),
      onChanged: (selecionado) {
        if (selecionado == null || selecionado == _todos) {
          onChanged(null);
        } else {
          onChanged(selecionado);
        }
      },
    );
  }

  Widget _buildFiltros() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 220,
                  child: _buildDropdown(
                    label: 'Categoria da máquina',
                    opcoes: _categorias,
                    valor: _categoriaSelecionada,
                    onChanged: (valor) =>
                        _atualizarFiltro(() => _categoriaSelecionada = valor),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _buildDropdown(
                    label: 'Máquina',
                    opcoes: _maquinas,
                    valor: _maquinaSelecionada,
                    onChanged: (valor) =>
                        _atualizarFiltro(() => _maquinaSelecionada = valor),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _buildDropdown(
                    label: 'Part number',
                    opcoes: _partnumbers,
                    valor: _partnumberSelecionado,
                    onChanged: (valor) =>
                        _atualizarFiltro(() => _partnumberSelecionado = valor),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildDropdown(
                    label: 'OS',
                    opcoes: _osOptions,
                    valor: _osSelecionada,
                    onChanged: (valor) =>
                        _atualizarFiltro(() => _osSelecionada = valor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoStatus() {
    final abertas = _contarOsPorStatus('Aberta');
    final finalizadas = _contarOsPorStatus('Finalizada');

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _StatusCountCard(
            key: const ValueKey('status_card_abertas'),
            titulo: 'OS abertas',
            total: abertas,
            icon: Icons.folder_open_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          _StatusCountCard(
            key: const ValueKey('status_card_finalizadas'),
            titulo: 'OS finalizadas',
            total: finalizadas,
            icon: Icons.task_alt_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ];

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cards[0], const SizedBox(height: 16), cards[1]],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildGraficos() {
    final abertas = _rows
        .where((row) => (row['status'] ?? '') == 'Aberta')
        .map((row) => row['os']?.toString() ?? '')
        .where((os) => os.isNotEmpty)
        .toList(growable: false);
    final finalizadas = _rows
        .where((row) => (row['status'] ?? '') == 'Finalizada')
        .map((row) => row['os']?.toString() ?? '')
        .where((os) => os.isNotEmpty)
        .toList(growable: false);
    final totaisAmostragens = _totaisGeraisAmostragens();

    return LayoutBuilder(
      builder: (context, constraints) {
        final charts = [
          _OsPieCard(
            key: const ValueKey('status_pie_abertas'),
            titulo: 'OS abertas',
            ordens: abertas,
          ),
          _OsPieCard(
            key: const ValueKey('status_pie_finalizadas'),
            titulo: 'OS finalizadas',
            ordens: finalizadas,
          ),
          _SamplingPieCard(
            key: const ValueKey('status_pie_amostragem'),
            titulo: 'Distribuição das amostragens',
            totais: totaisAmostragens,
          ),
        ];

        final isCompact = constraints.maxWidth < 900;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              charts[0],
              const SizedBox(height: 16),
              charts[1],
              const SizedBox(height: 16),
              charts[2],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: charts[0]),
                const SizedBox(width: 16),
                Expanded(child: charts[1]),
              ],
            ),
            const SizedBox(height: 16),
            charts[2],
          ],
        );
      },
    );
  }

  Widget _buildTabela(List<String> headers) {
    if (_loading && _allRows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rows.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhum dado encontrado com os filtros selecionados.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Resultados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('Total de OS: ${_rows.length}'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.4),
                  ),
                  columns: headers
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            _headerMap[h] ?? h,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  rows: _rows
                      .map(
                        (row) => DataRow(
                          cells: headers
                              .map(
                                (h) => DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 200,
                                    ),
                                    child: Text(
                                      _formatarValor(row, h),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headerMap.keys.toList();

    return Scaffold(
      appBar: const WindowBar(title: 'Status das OS', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _loading ? null : _carregar,
                    icon: const Icon(Icons.refresh),
                    label: _loading
                        ? const Text('Atualizando...')
                        : const Text('Atualizar'),
                  ),
                  if (_loading) ...[
                    const SizedBox(width: 16),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _buildFiltros(),
              const SizedBox(height: 16),
              _buildResumoStatus(),
              const SizedBox(height: 16),
              _buildGraficos(),
              const SizedBox(height: 16),
              Expanded(child: _buildTabela(headers)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCountCard extends StatelessWidget {
  const _StatusCountCard({
    super.key,
    required this.titulo,
    required this.total,
    required this.icon,
    required this.color,
  });
  final String titulo;
  final int total;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulo, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '$total',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OsPieCard extends StatelessWidget {
  const _OsPieCard({super.key, required this.titulo, required this.ordens});

  final String titulo;
  final List<String> ordens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = ordens.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (ordens.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma OS encontrada para este status.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              _PieChartWithLegend(
                centerLabel: '$total',
                centerDescription: total == 1 ? 'ordem' : 'ordens',
                slices: [
                  for (var i = 0; i < ordens.length; i++)
                    _PieSlice(label: 'OS ${ordens[i]}', value: 1),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SamplingPieCard extends StatelessWidget {
  const _SamplingPieCard({
    super.key,
    required this.titulo,
    required this.totais,
  });

  final String titulo;
  final Map<String, int> totais;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _statusKeys
        .map((key) => MapEntry(key, totais[key] ?? 0))
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    final total = entries.fold<int>(0, (acc, item) => acc + item.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma amostragem encontrada.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              _PieChartWithLegend(
                centerLabel: '$total',
                centerDescription: total == 1 ? 'amostragem' : 'amostragens',
                slices: [
                  for (final entry in entries)
                    _PieSlice(
                      label:
                          '${_headerMap[entry.key] ?? entry.key}: ${entry.value}',
                      value: entry.value.toDouble(),
                      colorOverride: _statusColor(entry.key, theme),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PieChartWithLegend extends StatelessWidget {
  const _PieChartWithLegend({
    required this.slices,
    required this.centerLabel,
    required this.centerDescription,
  });

  final List<_PieSlice> slices;
  final String centerLabel;
  final String centerDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _buildPalette(theme, slices.length);
    final sections = <PieChartSectionData>[];
    final legendEntries = <Widget>[];

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final color = slice.colorOverride ?? colors[i];
      sections.add(
        PieChartSectionData(
          color: color,
          value: slice.value,
          showTitle: false,
          radius: 56,
        ),
      );
      legendEntries.add(_LegendEntry(color: color, label: slice.label));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 420;
        final chart = SizedBox(
          height: 220,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 58,
                  startDegreeOffset: -90,
                ),
              ),
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      centerLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(centerDescription, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        );

        final legend = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: legendEntries,
        );

        if (isVertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [chart, const SizedBox(height: 16), legend],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: chart),
            const SizedBox(width: 16),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice({
    required this.label,
    required this.value,
    this.colorOverride,
  });

  final String label;
  final double value;
  final Color? colorOverride;
}

List<Color> _buildPalette(ThemeData theme, int count) {
  final candidates = <Color>[
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    theme.colorScheme.tertiary,
    theme.colorScheme.error,
    Colors.teal,
    Colors.deepOrange,
    Colors.indigo,
    Colors.pink,
    Colors.blueGrey,
    Colors.amber,
  ].whereType<Color>().toList();

  if (candidates.isEmpty) {
    candidates.add(Colors.blue);
  }

  return List<Color>.generate(
    count,
    (index) => candidates[index % candidates.length],
  );
}

Color _statusColor(String key, ThemeData theme) {
  switch (key) {
    case 'ok':
      return theme.colorScheme.primary;
    case 'alerta_abaixo':
      return Colors.orange;
    case 'alerta_acima':
      return Colors.deepOrange;
    case 'reprovada_abaixo':
      return theme.colorScheme.error;
    case 'reprovada_acima':
      return Colors.red.shade700;
    default:
      return theme.colorScheme.secondary;
  }
}
