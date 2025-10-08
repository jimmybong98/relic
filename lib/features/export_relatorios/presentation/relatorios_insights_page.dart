import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../../../services/report_service.dart';
import '../../../services/machine_service.dart';

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

const String _grupoTodos = '__grupo_all__';
const String _maquinaTodas = '__maquina_all__';

/// Página com indicadores adicionais e rankings de desempenho das O.S.
class RelatoriosInsightsPage extends StatefulWidget {
  const RelatoriosInsightsPage({super.key});

  @override
  State<RelatoriosInsightsPage> createState() => _RelatoriosInsightsPageState();
}

class _RelatoriosInsightsPageState extends State<RelatoriosInsightsPage> {
  final _osController = TextEditingController();
  final _reController = TextEditingController();
  bool _loading = true;
  bool _loadingMaquinas = false;
  String? _grupoFiltro;
  String? _maquinaFiltro;

  List<_OsResumo> _todos = const <_OsResumo>[];
  List<_OsResumo> _filtrados = const <_OsResumo>[];

  Map<String, int> _totaisStatus = const <String, int>{};
  int _totalAmostragens = 0;
  List<_RankingEntry> _rankingRes = const <_RankingEntry>[];
  List<_RankingEntry> _rankingMaquinas = const <_RankingEntry>[];
  List<_RankingEntry> _rankingPartnumbers = const <_RankingEntry>[];
  List<_OsResumo> _criticos = const <_OsResumo>[];
  List<String> _grupos = const <String>[];
  Map<String, List<String>> _maquinasPorGrupo = const <String, List<String>>{};
  Map<String, String> _grupoPorMaquina = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _osController.addListener(_onFiltroAtualizado);
    _reController.addListener(_onFiltroAtualizado);
    Future.microtask(() {
      _carregar();
      _carregarMaquinas();
    });
  }

  @override
  void dispose() {
    _osController
      ..removeListener(_onFiltroAtualizado)
      ..dispose();
    _reController
      ..removeListener(_onFiltroAtualizado)
      ..dispose();
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

  Future<void> _carregarMaquinas() async {
    setState(() => _loadingMaquinas = true);
    try {
      final lista = await MachineService().fetchMaquinas();
      final maquinasPorGrupo = <String, SplayTreeSet<String>>{};
      for (final maquina in lista) {
        final grupo = maquina.categoria.trim();
        final codigo = maquina.codigo.trim();
        if (grupo.isEmpty || codigo.isEmpty) continue;
        maquinasPorGrupo.putIfAbsent(grupo, SplayTreeSet.new).add(codigo);
      }

      if (!mounted) return;

      final gruposOrdenados = maquinasPorGrupo.keys.toList()..sort();
      final mapaOrdenado = {
        for (final entry in maquinasPorGrupo.entries)
          entry.key: entry.value.toList(growable: false),
      };
      final grupoPorMaquina = <String, String>{
        for (final entry in maquinasPorGrupo.entries)
          for (final codigo in entry.value) codigo: entry.key,
      };

      bool filtrosAlterados = false;
      setState(() {
        _grupos = gruposOrdenados;
        _maquinasPorGrupo = mapaOrdenado;
        _grupoPorMaquina = grupoPorMaquina;
        if (_grupoFiltro != null &&
            !_maquinasPorGrupo.containsKey(_grupoFiltro)) {
          _grupoFiltro = null;
          filtrosAlterados = true;
        }
        final maquinasValidas = _grupoFiltro == null
            ? const <String>[]
            : _maquinasPorGrupo[_grupoFiltro] ?? const <String>[];
        if (_maquinaFiltro != null &&
            !maquinasValidas.contains(_maquinaFiltro)) {
          _maquinaFiltro = null;
          filtrosAlterados = true;
        }
      });
      if (filtrosAlterados) {
        _onFiltroAtualizado();
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() => _loadingMaquinas = false);
    }
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
    final grupoFiltro = _grupoFiltro?.trim().toLowerCase();
    final maquinaFiltro = _maquinaFiltro?.trim().toLowerCase();

    final filtrados = base
        .where((item) {
          final matchOs =
              osFiltro.isEmpty || item.os.toLowerCase().contains(osFiltro);
          final matchRe =
              reFiltro.isEmpty ||
              item.reAmostragens.keys.any(
                (re) => re.toLowerCase().contains(reFiltro),
              );
          final gruposItem = _gruposRelacionados(item)
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet();
          final maquinasItem = item.maquinas
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet();
          final matchGrupo = grupoFiltro == null
              ? true
              : gruposItem.contains(grupoFiltro);
          final matchMaquina = maquinaFiltro == null
              ? true
              : maquinasItem.contains(maquinaFiltro);
          return matchOs && matchRe && matchGrupo && matchMaquina;
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

  Iterable<String> _gruposRelacionados(_OsResumo item) {
    if (item.categorias.isNotEmpty) {
      return item.categorias;
    }
    if (_grupoPorMaquina.isEmpty) {
      return const Iterable<String>.empty();
    }
    final relacionados = <String>{};
    for (final maquina in item.maquinas) {
      final chave = maquina.trim();
      final grupo = _grupoPorMaquina[chave] ?? _grupoPorMaquina[maquina];
      if (grupo != null && grupo.isNotEmpty) {
        relacionados.add(grupo);
      }
    }
    return relacionados;
  }

  void _limparFiltros() {
    _osController.text = '';
    _reController.text = '';
    _grupoFiltro = null;
    _maquinaFiltro = null;
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
    final grupoItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: _grupoTodos, child: Text('Todos')),
      ..._grupos.map(
        (grupo) => DropdownMenuItem<String>(value: grupo, child: Text(grupo)),
      ),
    ];
    final maquinasDisponiveis = _grupoFiltro == null
        ? const <String>[]
        : _maquinasPorGrupo[_grupoFiltro] ?? const <String>[];
    final maquinaItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: _maquinaTodas,
        child: Text('Todas'),
      ),
      ...maquinasDisponiveis.map(
        (maquina) =>
            DropdownMenuItem<String>(value: maquina, child: Text(maquina)),
      ),
    ];
    final grupoValue = _grupoFiltro ?? _grupoTodos;
    final maquinaValue = _grupoFiltro == null
        ? null
        : _maquinaFiltro ?? _maquinaTodas;

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
              child: DropdownButtonFormField<String>(
                key: ValueKey('grupo-$grupoValue'),
                initialValue: grupoValue,
                items: grupoItems,
                decoration: const InputDecoration(
                  labelText: 'Grupo de máquina',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    if (value == null || value == _grupoTodos) {
                      _grupoFiltro = null;
                      _maquinaFiltro = null;
                    } else {
                      _grupoFiltro = value;
                      final maquinasValidas =
                          _maquinasPorGrupo[_grupoFiltro] ?? const <String>[];
                      if (!maquinasValidas.contains(_maquinaFiltro)) {
                        _maquinaFiltro = null;
                      }
                    }
                  });
                  _onFiltroAtualizado();
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey('maquina-${maquinaValue ?? 'nenhuma'}'),
                initialValue: maquinaValue,
                items: maquinaItems,
                decoration: const InputDecoration(
                  labelText: 'Máquina',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: Text(
                  _loadingMaquinas
                      ? 'Carregando...'
                      : _grupoFiltro == null
                      ? 'Selecione um grupo'
                      : 'Todas',
                ),
                disabledHint: Text(
                  _loadingMaquinas ? 'Carregando...' : 'Selecione um grupo',
                ),
                onChanged: (_grupoFiltro == null || _loadingMaquinas)
                    ? null
                    : (value) {
                        setState(() {
                          if (value == null || value == _maquinaTodas) {
                            _maquinaFiltro = null;
                          } else {
                            _maquinaFiltro = value;
                          }
                        });
                        _onFiltroAtualizado();
                      },
              ),
            ),
            if (_osController.text.isNotEmpty ||
                _reController.text.isNotEmpty ||
                _grupoFiltro != null ||
                _maquinaFiltro != null)
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
