import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../../../services/report_service.dart';

const String _statusTodos = '__all__';
const Map<String, String> _statusLabels = {
  'reprovada_abaixo': 'Reprovada (Abaixo)',
  'alerta_abaixo': 'Alerta (Abaixo)',
  'ok': 'OK',
  'alerta_acima': 'Alerta (Acima)',
  'reprovada_acima': 'Reprovada (Acima)',
};

const Map<String, Color> _statusColors = {
  'ok': Color(0xFF26A69A),
  'alerta_abaixo': Color(0xFFFFB74D),
  'alerta_acima': Color(0xFFFFD54F),
  'reprovada_abaixo': Color(0xFFE57373),
  'reprovada_acima': Color(0xFFEF5350),
};

/// Página com indicadores adicionais e rankings de desempenho das O.S.
class RelatoriosInsightsPage extends StatefulWidget {
  const RelatoriosInsightsPage({super.key});

  @override
  State<RelatoriosInsightsPage> createState() => _RelatoriosInsightsPageState();
}

class _RelatoriosInsightsPageState extends State<RelatoriosInsightsPage> {
  final _osController = TextEditingController();
  final _reController = TextEditingController();
  final _statusController = TextEditingController();
  final FocusNode _statusFocusNode = FocusNode();

  bool _loading = true;
  String _statusFiltro = _statusTodos;

  List<_OsResumo> _todos = const <_OsResumo>[];
  List<_OsResumo> _filtrados = const <_OsResumo>[];

  Map<String, int> _totaisStatus = const <String, int>{};
  int _totalAmostragens = 0;
  List<_RankingEntry> _rankingRes = const <_RankingEntry>[];
  List<_RankingEntry> _rankingMaquinas = const <_RankingEntry>[];
  List<_RankingEntry> _rankingPartnumbers = const <_RankingEntry>[];
  List<_OsResumo> _criticos = const <_OsResumo>[];

  @override
  void initState() {
    super.initState();
    _osController.addListener(_onFiltroAtualizado);
    _reController.addListener(_onFiltroAtualizado);
    Future.microtask(_carregar);
  }

  @override
  void dispose() {
    _osController
      ..removeListener(_onFiltroAtualizado)
      ..dispose();
    _reController
      ..removeListener(_onFiltroAtualizado)
      ..dispose();
    _statusController.dispose();
    _statusFocusNode.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final data = await ReportService().fetchOsStatusOverview();
    final todos = data
        .map((raw) => _OsResumo.fromRaw(raw))
        .whereType<_OsResumo>()
        .toList(growable: false);
    if (!mounted) return;
    final indicadores = _gerarIndicadores(todos);
    setState(() {
      _todos = todos;
      _aplicarIndicadores(indicadores);
      _loading = false;
    });
  }

  void _onFiltroAtualizado() {
    if (!_loading) {
      final indicadores = _gerarIndicadores(_todos);
      setState(() => _aplicarIndicadores(indicadores));
    }
  }

  void _aplicarIndicadores(_Indicadores indicadores) {
    _filtrados = indicadores.filtrados;
    _totaisStatus = indicadores.totaisStatus;
    _totalAmostragens = indicadores.totalAmostragens;
    _rankingRes = indicadores.rankingRes;
    _rankingMaquinas = indicadores.rankingMaquinas;
    _rankingPartnumbers = indicadores.rankingPartnumbers;
    _criticos = indicadores.criticos;
  }

  _Indicadores _gerarIndicadores(List<_OsResumo> base) {
    final osFiltro = _osController.text.trim().toLowerCase();
    final reFiltro = _reController.text.trim().toLowerCase();
    final statusFiltro = _statusFiltro;

    final filtrados = base
        .where((item) {
          final matchOs =
              osFiltro.isEmpty || item.os.toLowerCase().contains(osFiltro);
          final matchRe =
              reFiltro.isEmpty ||
              item.reAmostragens.keys.any(
                (re) => re.toLowerCase().contains(reFiltro),
              );
          final matchStatus = statusFiltro == _statusTodos
              ? true
              : (item.statusCounts[statusFiltro] ?? 0) > 0;
          return matchOs && matchRe && matchStatus;
        })
        .toList(growable: false);

    final totais = {for (final key in _statusLabels.keys) key: 0};
    for (final item in filtrados) {
      item.statusCounts.forEach((key, value) {
        if (totais.containsKey(key)) {
          totais[key] = (totais[key] ?? 0) + value;
        }
      });
    }
    final totalAmostragens = totais.values.fold<int>(
      0,
      (acc, value) => acc + value,
    );

    final rankingRes = _calcularRankingRes(filtrados, filtro: reFiltro);
    final rankingMaquinas = _calcularRankingGenerico(
      filtrados,
      selector: (item) => item.maquinas,
    );
    final rankingPartnumbers = _calcularRankingGenerico(
      filtrados,
      selector: (item) => item.partnumbers,
    );

    final criticos =
        filtrados.where((item) => item.hasCritico).toList(growable: false)
          ..sort((a, b) => b.totalAlertas.compareTo(a.totalAlertas));

    return _Indicadores(
      filtrados: filtrados,
      totaisStatus: totais,
      totalAmostragens: totalAmostragens,
      rankingRes: rankingRes,
      rankingMaquinas: rankingMaquinas,
      rankingPartnumbers: rankingPartnumbers,
      criticos: criticos,
    );
  }

  List<_RankingEntry> _calcularRankingRes(
    List<_OsResumo> base, {
    String filtro = '',
  }) {
    final totais = <String, int>{};
    for (final item in base) {
      item.reAmostragens.forEach((re, total) {
        if (total <= 0) return;
        totais[re] = (totais[re] ?? 0) + total;
      });
    }
    if (filtro.isNotEmpty) {
      totais.removeWhere((key, value) => !key.toLowerCase().contains(filtro));
    }
    return _ordenarRanking(totais);
  }

  List<_RankingEntry> _calcularRankingGenerico(
    List<_OsResumo> base, {
    required List<String> Function(_OsResumo item) selector,
  }) {
    final totais = <String, int>{};
    for (final item in base) {
      final valores = selector(item);
      for (final valor in valores) {
        final label = valor.trim();
        if (label.isEmpty) continue;
        totais[label] = (totais[label] ?? 0) + 1;
      }
    }
    return _ordenarRanking(totais);
  }

  List<_RankingEntry> _ordenarRanking(Map<String, int> totais) {
    final entries =
        totais.entries
            .where((entry) => entry.value > 0)
            .map((entry) => _RankingEntry(entry.key, entry.value))
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    return entries.take(8).toList(growable: false);
  }

  void _sincronizarStatusController() {
    if (_statusFocusNode.hasFocus) {
      return;
    }
    if (_statusFiltro == _statusTodos) {
      if (_statusController.text.isNotEmpty) {
        _statusController.text = '';
      }
    } else {
      final label = _statusLabels[_statusFiltro] ?? _statusFiltro;
      if (_statusController.text != label) {
        _statusController.text = label;
      }
    }
  }

  void _limparFiltros() {
    _statusFiltro = _statusTodos;
    _osController.text = '';
    _reController.text = '';
    _statusController.text = '';
    _onFiltroAtualizado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Insights de relatórios', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _carregar,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (_todos.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(32),
                        children: const [
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nenhum dado disponível. Tente atualizar novamente em instantes.',
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFiltros(context),
                            const SizedBox(height: 16),
                            _buildResumoStatus(context),
                            const SizedBox(height: 16),
                            _buildRankings(context),
                            const SizedBox(height: 16),
                            _buildCriticos(context),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildFiltros(BuildContext context) {
    _sincronizarStatusController();
    final entries = <DropdownMenuEntry<String>>[
      const DropdownMenuEntry<String>(value: _statusTodos, label: 'Todos'),
      ..._statusLabels.entries.map(
        (entry) =>
            DropdownMenuEntry<String>(value: entry.key, label: entry.value),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _osController,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por O.S.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _reController,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por RE',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownMenu<String>(
                controller: _statusController,
                focusNode: _statusFocusNode,
                label: const Text('Status'),
                hintText: 'Todos',
                enableFilter: false,
                dropdownMenuEntries: entries,
                inputDecorationTheme: const InputDecorationTheme(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSelected: (value) {
                  if (value == null || value == _statusTodos) {
                    _statusFiltro = _statusTodos;
                    if (!_statusFocusNode.hasFocus) {
                      _statusController.text = '';
                    }
                  } else {
                    _statusFiltro = value;
                    final label = _statusLabels[value] ?? value;
                    if (_statusController.text != label) {
                      _statusController.text = label;
                    }
                  }
                  _onFiltroAtualizado();
                },
              ),
            ),
            if (_statusFiltro != _statusTodos ||
                _osController.text.isNotEmpty ||
                _reController.text.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: _limparFiltros,
                icon: const Icon(Icons.close),
                label: const Text('Limpar filtros'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoStatus(BuildContext context) {
    final theme = Theme.of(context);
    final total = math.max(_totalAmostragens, 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribuição das amostragens',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _statusLabels.keys.map((key) {
                final label = _statusLabels[key] ?? key;
                final valor = _totaisStatus[key] ?? 0;
                final percentual = valor / total;
                final cor = _statusColors[key] ?? theme.colorScheme.primary;
                return _ResumoStatusCard(
                  titulo: label,
                  quantidade: valor,
                  percentual: percentual,
                  cor: cor,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankings(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double largura = constraints.maxWidth;
        final double cardWidth = largura >= 1200
            ? (largura - 32) / 3
            : math.max(320, largura / 1.05);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _RankingCard(
              titulo: 'REs mais ativos',
              subtitulo: 'Quantidade de amostragens registradas',
              total: _rankingRes.fold<int>(0, (acc, item) => acc + item.total),
              entries: _rankingRes,
              largura: cardWidth,
            ),
            _RankingCard(
              titulo: 'Máquinas com mais O.S.',
              subtitulo: 'Ocorrências considerando os filtros aplicados',
              total: _rankingMaquinas.fold<int>(
                0,
                (acc, item) => acc + item.total,
              ),
              entries: _rankingMaquinas,
              largura: cardWidth,
            ),
            _RankingCard(
              titulo: 'Part numbers recorrentes',
              subtitulo: 'Frequência nas O.S. filtradas',
              total: _rankingPartnumbers.fold<int>(
                0,
                (acc, item) => acc + item.total,
              ),
              entries: _rankingPartnumbers,
              largura: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCriticos(BuildContext context) {
    if (_filtrados.isEmpty) {
      return const SizedBox.shrink();
    }
    final criticos = _criticos.take(12).toList(growable: false);
    if (criticos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Todas as O.S. filtradas estão dentro da normalidade.',
            style: Theme.of(context).textTheme.bodyLarge,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O.S. com atenção imediata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitoramento das ordens com alertas ou reprovações.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('O.S.')),
                DataColumn(label: Text('Status geral')),
                DataColumn(label: Text('Alertas')),
                DataColumn(label: Text('Máquinas envolvidas')),
              ],
              rows: criticos.map((item) {
                final alertas = item.statusCounts.entries
                    .where((entry) => entry.key != 'ok' && entry.value > 0)
                    .map(
                      (entry) =>
                          '${_statusLabels[entry.key] ?? entry.key}: ${entry.value}',
                    )
                    .join(' • ');
                final maquinas = item.maquinas.isEmpty
                    ? '-'
                    : item.maquinas.take(3).join(', ');
                return DataRow(
                  cells: [
                    DataCell(Text(item.os)),
                    DataCell(
                      Text(item.statusGeral.isEmpty ? '—' : item.statusGeral),
                    ),
                    DataCell(Text(alertas.isEmpty ? '—' : alertas)),
                    DataCell(Text(maquinas)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoStatusCard extends StatelessWidget {
  const _ResumoStatusCard({
    required this.titulo,
    required this.quantidade,
    required this.percentual,
    required this.cor,
  });

  final String titulo;
  final int quantidade;
  final double percentual;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = cor.withAlpha((0.2 * 255).round());
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '$quantidade',
            style: theme.textTheme.headlineSmall?.copyWith(color: cor),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentual.clamp(0, 1),
              minHeight: 6,
              color: cor,
              backgroundColor: backgroundColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(percentual * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.titulo,
    required this.subtitulo,
    required this.entries,
    required this.total,
    required this.largura,
  });

  final String titulo;
  final String subtitulo;
  final List<_RankingEntry> entries;
  final int total;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: largura,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitulo, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                Text('Sem dados para exibir', style: theme.textTheme.bodyMedium)
              else
                ...entries.map((entry) {
                  final percentual = total == 0
                      ? 0.0
                      : entry.total / total.toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                entry.label,
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.total}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percentual.clamp(0, 1),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingEntry {
  const _RankingEntry(this.label, this.total);

  final String label;
  final int total;
}

class _OsResumo {
  _OsResumo({
    required this.os,
    required this.statusGeral,
    required this.statusCounts,
    required this.maquinas,
    required this.categorias,
    required this.partnumbers,
    required this.reAmostragens,
  });

  final String os;
  final String statusGeral;
  final Map<String, int> statusCounts;
  final List<String> maquinas;
  final List<String> categorias;
  final List<String> partnumbers;
  final Map<String, int> reAmostragens;

  int get totalAlertas => statusCounts.entries
      .where((entry) => entry.key != 'ok')
      .fold(0, (acc, entry) => acc + entry.value);

  bool get hasCritico => totalAlertas > 0 || statusGeral.toLowerCase() != 'ok';

  factory _OsResumo.fromRaw(Map<String, dynamic> raw) {
    try {
      final statusCounts = <String, int>{};
      for (final key in _statusLabels.keys) {
        final valor = raw[key];
        statusCounts[key] = valor is num
            ? valor.toInt()
            : int.tryParse(valor?.toString() ?? '') ?? 0;
      }
      final maquinas =
          (raw['maquinas'] as List?)
              ?.whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      final categorias =
          (raw['categorias'] as List?)
              ?.whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      final partnumbers =
          (raw['partnumbers'] as List?)
              ?.whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];

      final reAmostragens = <String, int>{};
      final amostragens = raw['amostragens_por_re'];
      if (amostragens is List) {
        for (final item in amostragens) {
          if (item is! Map) continue;
          final re = item['re']?.toString().trim() ?? '';
          if (re.isEmpty) continue;
          final total = item['total'];
          final valor = total is num
              ? total.toInt()
              : int.tryParse(total?.toString() ?? '') ?? 0;
          if (valor <= 0) continue;
          reAmostragens[re] = valor;
        }
      } else if (amostragens is Map) {
        amostragens.forEach((key, value) {
          final re = key?.toString().trim() ?? '';
          if (re.isEmpty) return;
          final valor = value is num
              ? value.toInt()
              : int.tryParse(value?.toString() ?? '') ?? 0;
          if (valor <= 0) return;
          reAmostragens[re] = valor;
        });
      }

      return _OsResumo(
        os: raw['os']?.toString() ?? '',
        statusGeral: raw['status']?.toString() ?? '',
        statusCounts: statusCounts,
        maquinas: maquinas,
        categorias: categorias,
        partnumbers: partnumbers,
        reAmostragens: reAmostragens,
      );
    } catch (_) {
      return _OsResumo(
        os: '',
        statusGeral: '',
        statusCounts: {for (final key in _statusLabels.keys) key: 0},
        maquinas: const <String>[],
        categorias: const <String>[],
        partnumbers: const <String>[],
        reAmostragens: const <String, int>{},
      );
    }
  }
}

class _Indicadores {
  const _Indicadores({
    required this.filtrados,
    required this.totaisStatus,
    required this.totalAmostragens,
    required this.rankingRes,
    required this.rankingMaquinas,
    required this.rankingPartnumbers,
    required this.criticos,
  });

  final List<_OsResumo> filtrados;
  final Map<String, int> totaisStatus;
  final int totalAmostragens;
  final List<_RankingEntry> rankingRes;
  final List<_RankingEntry> rankingMaquinas;
  final List<_RankingEntry> rankingPartnumbers;
  final List<_OsResumo> criticos;
}
