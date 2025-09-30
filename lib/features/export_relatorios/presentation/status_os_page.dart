import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:admin/widgets/window_bar.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../screens/dashboard/components/personnel_report_chart.dart';
import '../../../screens/dashboard/components/operator_report_chart.dart';
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

  Timer? _autoRefreshTimer;

  List<String> _categorias = const <String>[];
  List<String> _maquinas = const <String>[];
  Map<String, List<String>> _maquinasPorCategoria =
      const <String, List<String>>{};
  List<String> _partnumbers = const <String>[];
  List<String> _osOptions = const <String>[];
  List<String> _resOptions = const <String>[];

  String? _categoriaSelecionada;
  String? _maquinaSelecionada;
  String? _partnumberSelecionado;
  String? _osSelecionada;
  String? _reSelecionado;

  final TextEditingController _categoriaController = TextEditingController();
  final TextEditingController _maquinaController = TextEditingController();
  final TextEditingController _partnumberController = TextEditingController();
  final TextEditingController _osController = TextEditingController();
  final TextEditingController _reController = TextEditingController();

  final FocusNode _categoriaFocusNode =
      FocusNode(debugLabel: 'categoriaDropdown');
  final FocusNode _maquinaFocusNode =
      FocusNode(debugLabel: 'maquinaDropdown');
  final FocusNode _partnumberFocusNode =
      FocusNode(debugLabel: 'partnumberDropdown');
  final FocusNode _osFocusNode = FocusNode(debugLabel: 'osDropdown');
  final FocusNode _reFocusNode = FocusNode(debugLabel: 'reDropdown');

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _loading) return;
      _carregar();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _categoriaController.dispose();
    _maquinaController.dispose();
    _partnumberController.dispose();
    _osController.dispose();
    _reController.dispose();
    _categoriaFocusNode.dispose();
    _maquinaFocusNode.dispose();
    _partnumberFocusNode.dispose();
    _osFocusNode.dispose();
    _reFocusNode.dispose();
    super.dispose();
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
          final reCounts = <_ReSamplingCount>[];
          final amostragensPorRe = mapa['amostragens_por_re'];
          if (amostragensPorRe is List) {
            for (final entry in amostragensPorRe) {
              if (entry is! Map) continue;
              final re = (entry['re'] ?? '').toString().trim();
              if (re.isEmpty) continue;
              final totalRaw = entry['total'];
              final total = totalRaw is num
                  ? totalRaw.toInt()
                  : int.tryParse(totalRaw?.toString() ?? '') ?? 0;
              if (total <= 0) continue;
              reCounts.add(_ReSamplingCount(re: re, total: total));
            }
          } else if (amostragensPorRe is Map) {
            amostragensPorRe.forEach((key, value) {
              final re = (key ?? '').toString().trim();
              if (re.isEmpty) return;
              final total = value is num
                  ? value.toInt()
                  : int.tryParse(value?.toString() ?? '') ?? 0;
              if (total <= 0) return;
              reCounts.add(_ReSamplingCount(re: re, total: total));
            });
          }
          mapa['amostragens_por_re'] = reCounts;
          return mapa;
        })
        .toList(growable: false);

    final categorias = SplayTreeSet<String>();
    final maquinas = SplayTreeSet<String>();
    final maquinasPorCategoria = <String, SplayTreeSet<String>>{};
    final partnumbers = SplayTreeSet<String>();
    final ordens = SplayTreeSet<String>();
    final res = SplayTreeSet<String>();

    for (final row in parsed) {
      categorias.addAll(row['categorias'].cast<String>());
      final maquinasDaLinha = row['maquinas'].cast<String>();
      maquinas.addAll(maquinasDaLinha);
      for (final categoria in row['categorias'].cast<String>()) {
        final bucket = maquinasPorCategoria.putIfAbsent(
          categoria,
          () => SplayTreeSet<String>(),
        );
        bucket.addAll(maquinasDaLinha);
      }
      partnumbers.addAll(row['partnumbers'].cast<String>());
      ordens.add(row['os'] as String);
      final amostragens = row['amostragens_por_re'];
      if (amostragens is List<_ReSamplingCount>) {
        for (final item in amostragens) {
          res.add(item.re);
        }
      }
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
    if (categoriaSelecionada != null) {
      final maquinasDoGrupo = maquinasPorCategoria[categoriaSelecionada];
      if (maquinasDoGrupo == null ||
          !maquinasDoGrupo.contains(maquinaSelecionada)) {
        maquinaSelecionada = null;
      }
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
    var reSelecionado = _reSelecionado;
    if (reSelecionado != null && !res.contains(reSelecionado)) {
      reSelecionado = null;
    }

    final filtrado = _filtrarLista(
      parsed,
      categoria: categoriaSelecionada,
      maquina: maquinaSelecionada,
      partnumber: partnumberSelecionado,
      os: osSelecionada,
      re: reSelecionado,
    );

    setState(() {
      _allRows = parsed;
      _rows = filtrado;
      _categorias = categorias.toList(growable: false);
      _maquinas = maquinas.toList(growable: false);
      _maquinasPorCategoria = maquinasPorCategoria.map(
        (key, value) => MapEntry(key, value.toList(growable: false)),
      );
      _partnumbers = partnumbers.toList(growable: false);
      _osOptions = ordens.toList(growable: false);
      _resOptions = res.toList(growable: false);
      _categoriaSelecionada = categoriaSelecionada;
      _maquinaSelecionada = maquinaSelecionada;
      _partnumberSelecionado = partnumberSelecionado;
      _osSelecionada = osSelecionada;
      _reSelecionado = reSelecionado;
      _atualizarTextoDropdown(
        _categoriaController,
        categoriaSelecionada,
        _categoriaFocusNode,
      );
      _atualizarTextoDropdown(
        _maquinaController,
        maquinaSelecionada,
        _maquinaFocusNode,
      );
      _atualizarTextoDropdown(
        _partnumberController,
        partnumberSelecionado,
        _partnumberFocusNode,
      );
      _atualizarTextoDropdown(_osController, osSelecionada, _osFocusNode);
      _atualizarTextoDropdown(_reController, reSelecionado, _reFocusNode);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _filtrarLista(
    List<Map<String, dynamic>> base, {
    String? categoria,
    String? maquina,
    String? partnumber,
    String? os,
    String? re,
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
          final reAmostragens = row['amostragens_por_re'];

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
          if (re != null && re.isNotEmpty) {
            final contemRe =
                reAmostragens is List<_ReSamplingCount> &&
                reAmostragens.any((item) => item.re == re);
            if (!contemRe) {
              return false;
            }
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
        re: _reSelecionado,
      );
    });
  }

  List<String> _obterMaquinasDisponiveis() {
    final categoria = _categoriaSelecionada;
    if (categoria == null || categoria.isEmpty) {
      return _maquinas;
    }
    return _maquinasPorCategoria[categoria] ?? const <String>[];
  }

  void _atualizarTextoDropdown(
    TextEditingController controller,
    String? valorSelecionado,
    FocusNode focusNode,
  ) {
    final texto = valorSelecionado ?? '';
    if (controller.text == texto) return;

    final shouldUpdate = valorSelecionado != null || !focusNode.hasFocus;
    if (!shouldUpdate) return;

    controller.value = controller.value.copyWith(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
      composing: TextRange.empty,
    );
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

  Map<String, int> _totaisGeraisAmostragensPorRe() {
    final totais = <String, int>{};
    final filtroRe = _reSelecionado?.trim();
    for (final row in _rows) {
      final lista = row['amostragens_por_re'];
      if (lista is! List<_ReSamplingCount>) continue;
      for (final item in lista) {
        if (item.total <= 0) continue;
        if (filtroRe != null && filtroRe.isNotEmpty && item.re != filtroRe) {
          continue;
        }
        totais[item.re] = (totais[item.re] ?? 0) + item.total;
      }
    }
    return totais;
  }

  Widget _buildDropdown({
    required String label,
    required List<String> opcoes,
    required String? valor,
    required ValueChanged<String?> onChanged,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    _atualizarTextoDropdown(controller, valor, focusNode);

    final entries = <DropdownMenuEntry<String>>[
      const DropdownMenuEntry<String>(value: _todos, label: 'Todos'),
      ...opcoes.map(
        (opcao) => DropdownMenuEntry<String>(value: opcao, label: opcao),
      ),
    ];

    return DropdownMenu<String>(
      controller: controller,
      label: Text(label),
      hintText: 'Todos',
      dropdownMenuEntries: entries,
      enableFilter: true,
      requestFocusOnTap: true,
      initialSelection: valor,
      focusNode: focusNode,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onSelected: (selecionado) {
        if (selecionado == null || selecionado == _todos) {
          onChanged(null);
        } else {
          onChanged(selecionado);
        }
      },
    );
  }

  Widget _buildFiltros() {
    const gap = 12.0;

    final dropdowns = <Widget>[
      _buildDropdown(
        label: 'Grupo de máquina',
        opcoes: _categorias,
        valor: _categoriaSelecionada,
        controller: _categoriaController,
        focusNode: _categoriaFocusNode,
        onChanged: (valor) => _atualizarFiltro(() {
          _categoriaSelecionada = valor;
          _atualizarTextoDropdown(
            _categoriaController,
            _categoriaSelecionada,
            _categoriaFocusNode,
          );
          if (_categoriaSelecionada != null) {
            final maquinasDisponiveis =
                _maquinasPorCategoria[_categoriaSelecionada];
            if (maquinasDisponiveis == null ||
                !maquinasDisponiveis.contains(_maquinaSelecionada)) {
              _maquinaSelecionada = null;
              _atualizarTextoDropdown(
                _maquinaController,
                _maquinaSelecionada,
                _maquinaFocusNode,
              );
            }
          }
        }),
      ),
      _buildDropdown(
        label: 'Máquina',
        opcoes: _obterMaquinasDisponiveis(),
        valor: _maquinaSelecionada,
        controller: _maquinaController,
        focusNode: _maquinaFocusNode,
        onChanged: (valor) => _atualizarFiltro(() {
          _maquinaSelecionada = valor;
          _atualizarTextoDropdown(
            _maquinaController,
            _maquinaSelecionada,
            _maquinaFocusNode,
          );
        }),
      ),
      _buildDropdown(
        label: 'Partnumber',
        opcoes: _partnumbers,
        valor: _partnumberSelecionado,
        controller: _partnumberController,
        focusNode: _partnumberFocusNode,
        onChanged: (valor) => _atualizarFiltro(() {
          _partnumberSelecionado = valor;
          _atualizarTextoDropdown(
            _partnumberController,
            _partnumberSelecionado,
            _partnumberFocusNode,
          );
        }),
      ),
      _buildDropdown(
        label: 'OS',
        opcoes: _osOptions,
        valor: _osSelecionada,
        controller: _osController,
        focusNode: _osFocusNode,
        onChanged: (valor) => _atualizarFiltro(() {
          _osSelecionada = valor;
          _atualizarTextoDropdown(_osController, _osSelecionada, _osFocusNode);
        }),
      ),
      _buildDropdown(
        label: 'RE',
        opcoes: _resOptions,
        valor: _reSelecionado,
        controller: _reController,
        focusNode: _reFocusNode,
        onChanged: (valor) => _atualizarFiltro(() {
          _reSelecionado = valor;
          _atualizarTextoDropdown(_reController, _reSelecionado, _reFocusNode);
        }),
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemCount = dropdowns.length;
                  if (itemCount == 0) {
                    return const SizedBox.shrink();
                  }

                  final maxWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.of(context).size.width;
                  var spacing = gap;
                  if (itemCount > 1 && maxWidth.isFinite) {
                    final requiredSpacing = spacing * (itemCount - 1);
                    if (requiredSpacing > maxWidth) {
                      spacing = maxWidth / (itemCount - 1 + itemCount);
                    }
                  }
                  final totalSpacing = spacing * (itemCount - 1);
                  final availableForItems = (maxWidth - totalSpacing).clamp(
                    0.0,
                    double.infinity,
                  );
                  final itemWidth = itemCount > 0
                      ? availableForItems / itemCount
                      : 0.0;

                  return Row(
                    children: [
                      for (var i = 0; i < itemCount; i++) ...[
                        SizedBox(width: itemWidth, child: dropdowns[i]),
                        if (i < itemCount - 1) SizedBox(width: spacing),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
    final totaisAmostragensPorRe = _totaisGeraisAmostragensPorRe();

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
            totaisPorRe: totaisAmostragensPorRe,
          ),
        ];

        final isCompact = constraints.maxWidth < 720;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < charts.length; i++) ...[
                charts[i],
                if (i < charts.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        final osRow = Row(
          children: [
            Expanded(child: charts[0]),
            const SizedBox(width: 16),
            Expanded(child: charts[1]),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [osRow, const SizedBox(height: 16), charts[2]],
        );
      },
    );
  }

  Widget _buildTabela() {
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

    final osSet = SplayTreeSet<String>();
    for (final row in _rows) {
      final os = row['os']?.toString().trim() ?? '';
      if (os.isNotEmpty) {
        osSet.add(os);
      }
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: PersonnelReportChart(
              osList: osSet.toList(growable: false),
              showSearchControls: false,
              withContainer: false,
              reFilter: _reSelecionado,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Status das OS', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardColor = Theme.of(context).cardColor;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OperatorReportChart(backgroundColor: cardColor),
                    const SizedBox(height: 24),
                    Center(
                      child: Image.asset(
                        'assets/images/traco.png',
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 16),
                    _buildFiltros(),
                    const SizedBox(height: 16),
                    _buildGraficos(),
                    const SizedBox(height: 16),
                    _buildTabela(),
                  ],
                ),
              ),
            );
          },
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
              _OsInteractivePie(
                centerLabel: '$total',
                centerDescription: total == 1 ? 'ordem' : 'ordens',
                slices: [
                  for (final os in ordens) _PieSlice(label: 'OS $os', value: 1),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OsInteractivePie extends StatefulWidget {
  const _OsInteractivePie({
    required this.slices,
    required this.centerLabel,
    required this.centerDescription,
  });

  final List<_PieSlice> slices;
  final String centerLabel;
  final String centerDescription;

  @override
  State<_OsInteractivePie> createState() => _OsInteractivePieState();
}

class _OsInteractivePieState extends State<_OsInteractivePie> {
  int _touchedIndex = -1;

  @override
  void didUpdateWidget(covariant _OsInteractivePie oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldResetIndex =
        _touchedIndex >= widget.slices.length ||
        (_touchedIndex >= 0 &&
            _touchedIndex < oldWidget.slices.length &&
            oldWidget.slices[_touchedIndex].label !=
                widget.slices[_touchedIndex].label);

    if (shouldResetIndex) {
      setState(() => _touchedIndex = -1);
    }
  }

  void _handleTouch(FlTouchEvent event, PieTouchResponse? response) {
    final newIndex =
        event.isInterestedForInteractions && response?.touchedSection != null
        ? response!.touchedSection!.touchedSectionIndex
        : -1;
    if (newIndex != _touchedIndex) {
      setState(() => _touchedIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _buildPalette(theme, widget.slices.length);
    final sectionsSpace = widget.slices.length >= 32
        ? 0.5
        : widget.slices.length >= 18
        ? 1.0
        : 2.0;

    final hoveredLabel =
        (_touchedIndex >= 0 && _touchedIndex < widget.slices.length)
        ? widget.slices[_touchedIndex].label
        : null;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.8),
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final chartSize = math.max(180.0, math.min(availableWidth, 320.0));
        final maxRadius = chartSize / 2 - 12;
        final baseRadius = math.max(42.0, math.min(56.0, maxRadius));
        final touchedRadius = math.min(baseRadius + 6, maxRadius);
        final centerSpace = math.max(chartSize * 0.26, 46.0);
        final badgeOffset = chartSize < 240 ? 1.04 : 1.12;

        final adjustedSections = <PieChartSectionData>[];
        for (var i = 0; i < widget.slices.length; i++) {
          final slice = widget.slices[i];
          final color = slice.colorOverride ?? colors[i];
          final isTouched = i == _touchedIndex;
          adjustedSections.add(
            PieChartSectionData(
              color: color,
              value: slice.value,
              showTitle: false,
              radius: isTouched ? touchedRadius : baseRadius,
              badgeWidget: _OsSliceBadge(
                label: slice.label,
                visible: isTouched,
              ),
              badgePositionPercentageOffset: badgeOffset,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: chartSize,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sections: adjustedSections,
                      sectionsSpace: sectionsSpace,
                      centerSpaceRadius: centerSpace,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(touchCallback: _handleTouch),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.centerLabel,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.centerDescription,
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 28,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: hoveredLabel == null
                    ? const SizedBox.shrink()
                    : Center(
                        child: Text(
                          hoveredLabel,
                          textAlign: TextAlign.center,
                          style: labelStyle,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OsSliceBadge extends StatelessWidget {
  const _OsSliceBadge({required this.label, required this.visible});

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface.withOpacity(0.94);
    final outline = theme.colorScheme.outline.withOpacity(0.5);

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: visible ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: outline, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
    required this.totaisPorRe,
  });

  final String titulo;
  final Map<String, int> totais;
  final Map<String, int> totaisPorRe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _statusKeys
        .map((key) => MapEntry(key, totais[key] ?? 0))
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    final total = entries.fold<int>(0, (acc, item) => acc + item.value);
    final reEntries =
        totaisPorRe.entries
            .where((entry) => entry.value > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final diff = b.value.compareTo(a.value);
            if (diff != 0) return diff;
            return a.key.compareTo(b.key);
          });

    Widget buildChart() {
      if (total == 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Nenhuma amostragem encontrada.',
            style: theme.textTheme.bodyMedium,
          ),
        );
      }

      return _InteractivePieWithLegend(
        centerLabel: '$total',
        centerDescription: total == 1 ? 'amostragem' : 'amostragens',
        slices: [
          for (final entry in entries)
            _PieSlice(
              label: '${_headerMap[entry.key] ?? entry.key}: ${entry.value}',
              value: entry.value.toDouble(),
              colorOverride: _statusColor(entry.key, theme),
            ),
        ],
      );
    }

    Widget buildReList() {
      final headerStyle = theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      );
      final reStyle = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      );
      final countStyle = theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
      );
      final captionStyle = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      );

      if (reEntries.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ciclo de amostragens por RE', style: headerStyle),
            const SizedBox(height: 8),
            Text('Nenhuma amostragem registrada.', style: captionStyle),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ciclo de amostragens por RE', style: headerStyle),
          const SizedBox(height: 8),
          for (final entry in reEntries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'RE ${entry.key}',
                      style: reStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${entry.value}', style: countStyle),
                  const SizedBox(width: 4),
                  Text(
                    entry.value == 1 ? 'amostragem' : 'amostragens',
                    style: captionStyle,
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 680;
                final chart = buildChart();
                final reList = buildReList();

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [chart, const SizedBox(height: 16), reList],
                  );
                }

                final listWidth = math.max(
                  220.0,
                  math.min(320.0, constraints.maxWidth * 0.45),
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 24),
                    SizedBox(width: listWidth, child: reList),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractivePieWithLegend extends StatefulWidget {
  const _InteractivePieWithLegend({
    required this.slices,
    required this.centerLabel,
    required this.centerDescription,
  });

  final List<_PieSlice> slices;
  final String centerLabel;
  final String centerDescription;

  @override
  State<_InteractivePieWithLegend> createState() =>
      _InteractivePieWithLegendState();
}

class _InteractivePieWithLegendState extends State<_InteractivePieWithLegend> {
  int _touchedIndex = -1;

  @override
  void didUpdateWidget(covariant _InteractivePieWithLegend oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldResetIndex =
        _touchedIndex >= widget.slices.length ||
        (_touchedIndex >= 0 &&
            _touchedIndex < oldWidget.slices.length &&
            oldWidget.slices[_touchedIndex].label !=
                widget.slices[_touchedIndex].label);

    if (shouldResetIndex) {
      setState(() => _touchedIndex = -1);
    }
  }

  void _handleTouch(FlTouchEvent event, PieTouchResponse? response) {
    final newIndex =
        event.isInterestedForInteractions && response?.touchedSection != null
        ? response!.touchedSection!.touchedSectionIndex
        : -1;
    if (newIndex != _touchedIndex) {
      setState(() => _touchedIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _buildPalette(theme, widget.slices.length);
    final isDense = widget.slices.length > 8;
    final sectionsSpace = widget.slices.length >= 20
        ? 0.6
        : isDense
        ? 1.2
        : 2.0;
    final baseRadius = isDense ? 52.0 : 56.0;

    final hoveredLabel =
        (_touchedIndex >= 0 && _touchedIndex < widget.slices.length)
        ? widget.slices[_touchedIndex].label
        : null;
    final hoveredStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.82),
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final chartSize = math.min(math.max(180.0, availableWidth), 340.0);
        final maxRadius = chartSize / 2 - 14;
        final baseRadiusValue = math.max(40.0, math.min(baseRadius, maxRadius));
        final touchedRadius = math.min(baseRadiusValue + 6, maxRadius);
        final centerSpace = math.max(chartSize * 0.24, 48.0);

        final sections = <PieChartSectionData>[];
        final legendEntries = <Widget>[];

        for (var i = 0; i < widget.slices.length; i++) {
          final slice = widget.slices[i];
          final color = slice.colorOverride ?? colors[i];
          final isTouched = i == _touchedIndex;
          sections.add(
            PieChartSectionData(
              color: color,
              value: slice.value,
              showTitle: false,
              radius: isTouched ? touchedRadius : baseRadiusValue,
              borderSide: isTouched
                  ? BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.18),
                      width: 1.4,
                    )
                  : const BorderSide(color: Colors.transparent),
            ),
          );
          legendEntries.add(
            _LegendEntry(
              color: color,
              label: slice.label,
              highlighted: isTouched,
            ),
          );
        }

        final chart = SizedBox(
          height: chartSize,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: sectionsSpace,
                  centerSpaceRadius: centerSpace,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(touchCallback: _handleTouch),
                ),
              ),
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.centerLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.centerDescription,
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final hoveredIndicator = SizedBox(
          height: 28,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: hoveredLabel == null
                ? const SizedBox.shrink()
                : Center(
                    child: Text(
                      hoveredLabel,
                      textAlign: TextAlign.center,
                      style: hoveredStyle,
                    ),
                  ),
          ),
        );

        final legend = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: legendEntries,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            chart,
            const SizedBox(height: 12),
            hoveredIndicator,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: legend),
          ],
        );
      },
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.highlighted = false,
  });

  final Color color;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = highlighted
        ? theme.colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.45 : 0.6,
          )
        : Colors.transparent;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(highlighted ? 0.92 : 0.8),
      fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 180),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.36),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReSamplingCount {
  const _ReSamplingCount({required this.re, required this.total});

  final String re;
  final int total;
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
  bool addUnique(List<Color> list, Color? color) {
    if (color == null) return false;
    if (list.any((existing) => existing.value == color.value)) {
      return false;
    }
    list.add(color);
    return true;
  }

  final candidates = <Color>[
    const Color(0xFF1E88E5), // blue
    const Color(0xFFE53935), // red
    const Color(0xFF43A047), // green
    const Color(0xFFFFC107), // yellow
    const Color(0xFF8E24AA), // purple
    const Color(0xFFFF7043), // orange
    const Color(0xFF00ACC1), // cyan
    const Color(0xFF7CB342), // light green
    const Color(0xFFF06292), // pink
    const Color(0xFF5C6BC0), // indigo
    const Color(0xFFFF8F00), // amber orange
    const Color(0xFF26A69A), // teal
    const Color(0xFFAB47BC), // violet
    const Color(0xFFD81B60), // magenta
  ];

  final palette = <Color>[];
  for (final color in candidates) {
    addUnique(palette, color);
  }

  addUnique(palette, theme.colorScheme.primary);
  addUnique(palette, theme.colorScheme.secondary);
  addUnique(palette, theme.colorScheme.tertiary);
  addUnique(palette, theme.colorScheme.error);

  if (palette.isEmpty) {
    palette.add(Colors.blueAccent);
  }

  if (count <= palette.length) {
    return palette.take(count).toList(growable: false);
  }

  final colors = <Color>[]..addAll(palette);
  const goldenRatio = 0.6180339887498949;
  var hue = 0.0;

  while (colors.length < count) {
    hue = (hue + goldenRatio) % 1.0;
    final saturation = 0.78;
    final value = 0.88;
    final color = HSVColor.fromAHSV(1, hue * 360, saturation, value).toColor();
    if (!colors.any((existing) => existing.value == color.value)) {
      colors.add(color);
    }
  }

  return colors.take(count).toList(growable: false);
}

Color _statusColor(String key, ThemeData theme) {
  switch (key) {
    case 'reprovada_abaixo':
      return Colors.red.shade400;
    case 'alerta_abaixo':
      return Colors.amber.shade400;
    case 'ok':
      return Colors.green.shade600;
    case 'alerta_acima':
      return Colors.amber.shade700;
    case 'reprovada_acima':
      return Colors.red.shade700;
    default:
      return theme.colorScheme.secondary;
  }
}
