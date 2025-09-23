import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../services/report_service.dart';
import 'package:intl/intl.dart';

/// Form that allows searching reports for either operators or preparers.
/// The user can choose to search by OS or by Partnumber + Operação.
class PersonnelReportChart extends StatefulWidget {
  const PersonnelReportChart({super.key});

  @override
  State<PersonnelReportChart> createState() => _PersonnelReportChartState();
}

class _PersonnelReportChartState extends State<PersonnelReportChart> {
  final _osCtrl = TextEditingController();
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();

  String _tipo = 'operador';
  String _modo = 'os';
  Future<List<Map<String, dynamic>>>? _future;
  final Map<String, Set<String>> _hiddenColumns = {
    'operador': <String>{},
    'preparador': <String>{},
  };
  final Map<String, List<String>> _columnOrders = {
    'operador': <String>[],
    'preparador': <String>[],
  };

  static const Map<String, Map<String, String>> _headerConfigs = {
    'preparador': {
      'os': 'OS',
      're_liberacao': 'RE Liberação',
      're_finalizacao': 'RE Finalização',
      'partnumber': 'Partnumber',
      'maquina': 'Máquina',
      'faixa_texto': 'Faixa',
      'created_at': 'Horário Inicial',
      'medicao': 'Medição Inicial',
      'medicao_final': 'Medição Final',
      'created_at_final': 'Horário Final',
    },
    'operador': {
      'os': 'OS',
      're_operador': 'RE',
      'created_at': 'Início',
      'retorno_at': 'Retorno',
      'partnumber': 'Partnumber',
      'maquina': 'Máquina',
      'titulo': 'Título',
      'instrumento': 'Instrumento',
      'faixa_texto': 'Faixa',
      'status': 'Status',
      'motivo': 'Motivo',
    },
  };

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    DateTime? dt = DateTime.tryParse(raw);
    if (dt != null) return dt.toLocal();
    if (!raw.contains('T') && raw.contains(' ')) {
      dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (dt != null) return dt.toLocal();
    }
    try {
      return DateFormat(
        "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
        'en_US',
      ).parseUtc(raw).toLocal();
    } catch (_) {}
    for (final pattern in const [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-ddTHH:mm:ss',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
    ]) {
      try {
        return DateFormat(pattern).parse(raw).toLocal();
      } catch (_) {}
    }
    return null;
  }

  String _formatDate(dynamic value) {
    final dt = _parseDateTime(value);
    if (dt != null) {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    }
    final raw = value?.toString() ?? '';
    if (raw.contains('T')) return raw.replaceAll('T', ' ');
    return raw;
  }

  int _compareByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dtA = a['__dt'] as DateTime?;
    final dtB = b['__dt'] as DateTime?;
    if (dtA == null && dtB == null) return 0;
    if (dtA == null) return 1;
    if (dtB == null) return -1;
    return dtA.compareTo(dtB);
  }

  List<Map<String, dynamic>> _withGroupHeaders(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <Map<String, dynamic>>[];
    var index = 0;
    while (index < rows.length) {
      final row = rows[index];
      final dt = row['__dt'] as DateTime?;
      if (dt == null) {
        result.add(row);
        index++;
        continue;
      }

      DateTime normalize(DateTime value) => DateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );

      final normalized = normalize(dt);
      final groupRows = <Map<String, dynamic>>[];
      while (index < rows.length) {
        final current = rows[index];
        final currentDt = current['__dt'] as DateTime?;
        if (currentDt == null) {
          break;
        }
        if (normalize(currentDt) != normalized) {
          break;
        }
        groupRows.add(current);
        index++;
      }

      result.add({
        '__isGroup': true,
        '__dt': normalized,
        'created_at': DateFormat(
          'dd/MM/yyyy HH:mm:ss',
        ).format(groupRows.first['__dt'] as DateTime),
      });

      final pauseRows = <Map<String, dynamic>>[];
      final otherRows = <Map<String, dynamic>>[];
      for (final item in groupRows) {
        final event = item['evento']?.toString();
        if (event == 'pausa_jornada') {
          pauseRows.add(item);
        } else {
          otherRows.add(item);
        }
      }

      result
        ..addAll(pauseRows)
        ..addAll(otherRows);
    }
    return result;
  }

  @override
  void dispose() {
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
  }

  void _ensureColumnState(Map<String, String> headerMap) {
    final allowedKeys = headerMap.keys.toList(growable: false);
    final allowedSet = allowedKeys.toSet();
    final order = _columnOrders.putIfAbsent(_tipo, () => <String>[]);
    final hidden = _hiddenColumns.putIfAbsent(_tipo, () => <String>{});
    order.removeWhere((key) => !allowedSet.contains(key));
    hidden.removeWhere((key) => !allowedSet.contains(key));
    for (final key in allowedKeys) {
      if (!order.contains(key)) {
        order.add(key);
      }
    }
  }

  void _hideColumn(String columnKey) {
    final headerMap = _headerConfigs[_tipo] ?? const {};
    _ensureColumnState(headerMap);
    final hidden = _hiddenColumns[_tipo]!;
    final order = _columnOrders[_tipo]!;
    final visibleCount = order.where((key) => !hidden.contains(key)).length;
    if (visibleCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mantenha ao menos uma coluna visível.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      hidden.add(columnKey);
    });
  }

  void _showColumn(String columnKey) {
    final headerMap = _headerConfigs[_tipo] ?? const {};
    _ensureColumnState(headerMap);
    setState(() {
      _hiddenColumns[_tipo]!.remove(columnKey);
    });
  }

  void _reorderVisibleColumn(String columnKey, int targetIndex) {
    final headerMap = _headerConfigs[_tipo] ?? const {};
    _ensureColumnState(headerMap);
    final hidden = _hiddenColumns[_tipo]!;
    if (hidden.contains(columnKey)) {
      return;
    }
    final order = _columnOrders[_tipo]!;
    final visible = [
      for (final key in order)
        if (!hidden.contains(key)) key,
    ];
    if (visible.length < 2) {
      return;
    }
    final oldIndex = visible.indexOf(columnKey);
    if (oldIndex == -1) {
      return;
    }
    if (targetIndex < 0 || targetIndex > visible.length) {
      return;
    }
    var adjustedIndex = targetIndex;
    if (adjustedIndex > oldIndex) {
      adjustedIndex -= 1;
    }
    if (adjustedIndex == oldIndex) {
      return;
    }
    final moved = visible.removeAt(oldIndex);
    visible.insert(adjustedIndex, moved);
    final hiddenOrder = [
      for (final key in order)
        if (hidden.contains(key)) key,
    ];
    setState(() {
      order
        ..clear()
        ..addAll(visible)
        ..addAll(hiddenOrder);
    });
  }

  Widget _buildColumnChip(
    BuildContext context,
    String columnKey,
    String label, {
    bool enableTooltip = true,
    bool enableDelete = true,
  }) {
    final chip = Chip(
      avatar: const Icon(Icons.drag_indicator, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      deleteIcon: enableDelete
          ? const Icon(Icons.visibility_off_outlined, size: 18)
          : null,
      onDeleted: enableDelete ? () => _hideColumn(columnKey) : null,
      deleteButtonTooltipMessage: enableDelete ? 'Ocultar coluna' : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (!enableTooltip) {
      return chip;
    }
    return Tooltip(message: 'Arraste para reordenar', child: chip);
  }

  Widget _buildReorderableChip(
    BuildContext context,
    Map<String, String> headerMap,
    String columnKey,
  ) {
    final label = headerMap[columnKey] ?? columnKey;
    return LongPressDraggable<String>(
      data: columnKey,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 6,
        color: Colors.transparent,
        child: _buildColumnChip(
          context,
          columnKey,
          label,
          enableTooltip: false,
          enableDelete: false,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: IgnorePointer(
          child: _buildColumnChip(
            context,
            columnKey,
            label,
            enableTooltip: false,
          ),
        ),
      ),
      child: _buildColumnChip(context, columnKey, label),
    );
  }

  Widget _buildDropTarget(
    BuildContext context,
    int targetIndex,
    int totalVisible,
  ) {
    final theme = Theme.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _reorderVisibleColumn(details.data, targetIndex);
      },
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty;
        final leftMargin = targetIndex == 0 ? 0.0 : 4.0;
        final rightMargin = targetIndex == totalVisible ? 0.0 : 4.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 12,
          height: 40,
          margin: EdgeInsets.only(
            left: leftMargin,
            right: rightMargin,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  Widget _buildHeaderLabel(
    String columnKey,
    String label,
    VoidCallback onHide,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Tooltip(
          message: 'Ocultar coluna',
          child: IconButton(
            icon: const Icon(Icons.visibility_off_outlined, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 18,
            onPressed: onHide,
          ),
        ),
      ],
    );
  }

  Widget _buildColumnManager(
    BuildContext context,
    Map<String, String> headerMap,
    List<String> visibleColumns,
    List<String> hiddenColumns,
  ) {
    if (headerMap.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hiddenColumns.isNotEmpty) ...[
          Text('Colunas ocultas', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hiddenColumns.map((key) {
              final label = headerMap[key] ?? key;
              return Tooltip(
                message: 'Mostrar coluna',
                child: ActionChip(
                  avatar: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(label),
                  onPressed: () => _showColumn(key),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text('Colunas visíveis', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final totalVisible = visibleColumns.length;
            final reorderChildren = <Widget>[];
            for (var index = 0; index < totalVisible; index++) {
              reorderChildren.add(
                _buildDropTarget(context, index, totalVisible),
              );
              final columnKey = visibleColumns[index];
              reorderChildren.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: KeyedSubtree(
                    key: ValueKey('visible_$columnKey'),
                    child: _buildReorderableChip(context, headerMap, columnKey),
                  ),
                ),
              );
            }
            reorderChildren.add(
              _buildDropTarget(context, totalVisible, totalVisible),
            );
            return Wrap(
              spacing: 0,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: reorderChildren,
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Arraste para mudar a ordem ou oculte colunas pelo ícone de olho.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  void _buscar() {
    Future<List<Map<String, dynamic>>> carregador() async {
      final service = ReportService();
      if (_modo == 'os') {
        final os = _osCtrl.text.trim();
        final section = _tipo == 'preparador' ? 'full' : 'amostragem';
        final data = await service.fetchOsReport(os, section: section);
        final rows = <Map<String, dynamic>>[];
        if (data != null) {
          if (_tipo == 'preparador') {
            String buildKey(Map<String, dynamic> map) {
              String normalize(dynamic value) {
                final str = value?.toString() ?? '';
                return str.trim();
              }

              return [
                normalize(map['partnumber']),
                normalize(map['operacao']),
                normalize(map['idx_medida']),
                normalize(map['titulo']),
                normalize(map['maquina']),
              ].join('|');
            }

            Map<String, dynamic>? findMatch(
              List<Map<String, dynamic>> source,
              String key,
            ) {
              for (final row in source) {
                if (row['__matchKey'] != key) continue;
                final createdFinal = row['created_at_final'];
                final medFinal = row['medicao_final'];
                final reFinal = row['re_finalizacao'];
                final hasFinalizacao =
                    (createdFinal != null &&
                        createdFinal.toString().isNotEmpty) ||
                    (medFinal != null && medFinal.toString().isNotEmpty) ||
                    (reFinal != null && reFinal.toString().isNotEmpty);
                if (!hasFinalizacao) return row;
              }
              return null;
            }

            final releaseRows = <Map<String, dynamic>>[];
            for (final e in (data['liberacao'] as List? ?? [])) {
              if (e is Map<String, dynamic>) {
                final createdAt = _formatDate(e['created_at']);
                releaseRows.add({
                  '__dt': _parseDateTime(e['created_at']),
                  '__matchKey': buildKey(e),
                  'os': e['os']?.toString() ?? '',
                  're_liberacao': e['re_preparador']?.toString() ?? '',
                  're_finalizacao': '',
                  'created_at': createdAt,
                  'created_at_final': '',
                  'partnumber': e['partnumber']?.toString() ?? '',
                  'operacao': e['operacao']?.toString() ?? '',
                  'maquina': e['maquina']?.toString() ?? '',
                  'faixa_texto': e['faixa_texto']?.toString() ?? '',
                  'medicao': e['medicao']?.toString() ?? '',
                  'medicao_final': '',
                  'idx_medida': e['idx_medida']?.toString() ?? '',
                  'titulo': e['titulo']?.toString() ?? '',
                });
              }
            }
            for (final e in (data['finalizacao'] as List? ?? [])) {
              if (e is Map<String, dynamic>) {
                final createdAt = _formatDate(e['created_at']);
                final key = buildKey(e);
                final row = findMatch(releaseRows, key);
                if (row != null) {
                  row['created_at_final'] = createdAt;
                  row['medicao_final'] = e['medicao']?.toString() ?? '';
                  row['re_finalizacao'] = e['re_preparador']?.toString() ?? '';
                  if (row['__dt'] == null) {
                    row['__dt'] = _parseDateTime(e['created_at']);
                  }
                } else {
                  releaseRows.add({
                    '__dt': _parseDateTime(e['created_at']),
                    '__matchKey': key,
                    'os': e['os']?.toString() ?? '',
                    're_liberacao': '',
                    're_finalizacao': e['re_preparador']?.toString() ?? '',
                    'created_at': '',
                    'created_at_final': createdAt,
                    'partnumber': e['partnumber']?.toString() ?? '',
                    'operacao': e['operacao']?.toString() ?? '',
                    'maquina': e['maquina']?.toString() ?? '',
                    'faixa_texto': e['faixa_texto']?.toString() ?? '',
                    'medicao': '',
                    'medicao_final': e['medicao']?.toString() ?? '',
                    'idx_medida': e['idx_medida']?.toString() ?? '',
                    'titulo': e['titulo']?.toString() ?? '',
                  });
                }
              }
            }
            for (final row in releaseRows) {
              row.remove('__matchKey');
            }
            rows.addAll(releaseRows);
          } else {
            final list = data[section];
            if (list is List) {
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  final createdAt = _formatDate(e['created_at']);
                  rows.add({
                    '__dt': _parseDateTime(e['created_at']),
                    'os': e['os']?.toString() ?? '',
                    're_operador': e['re_operador']?.toString() ?? '',
                    'created_at': createdAt,
                    'retorno_at': '',
                    'partnumber': e['partnumber']?.toString() ?? '',
                    'maquina': e['maquina']?.toString() ?? '',
                    'titulo': e['titulo']?.toString() ?? '',
                    'instrumento': e['instrumento']?.toString() ?? '',
                    'faixa_texto': e['faixa_texto']?.toString() ?? '',
                    'escolha': e['escolha']?.toString() ?? '',
                    'status': e['status']?.toString() ?? '',
                    'motivo': (e['motivo'] ?? '').toString(),
                    'evento': (e['evento'] ?? 'amostragem').toString(),
                  });
                }
              }
            }
            for (final e in (data['jornada'] as List? ?? [])) {
              if (e is Map<String, dynamic>) {
                final inicioRaw = e['pausa_at'] ?? e['created_at'];
                rows.add({
                  '__dt': _parseDateTime(inicioRaw),
                  'os': e['os']?.toString() ?? '',
                  're_operador': e['re_operador']?.toString() ?? '',
                  'created_at': _formatDate(inicioRaw),
                  'retorno_at': _formatDate(e['retorno_at']),
                  'partnumber': e['partnumber']?.toString() ?? '',
                  'maquina': '',
                  'titulo': 'Pausa de Jornada',
                  'instrumento': '',
                  'faixa_texto': '',
                  'escolha': '',
                  'status': 'Pausa de jornada',
                  'motivo': (e['motivo'] ?? '').toString(),
                  'evento': 'pausa_jornada',
                });
              }
            }
          }
        }
        rows.sort(_compareByDate);
        return _withGroupHeaders(rows);
      } else {
        final part = _partCtrl.text.trim();
        final op = _opCtrl.text.trim();
        final data = await service.fetchReleases(
          tipo: _tipo,
          partnumber: part,
          operacao: op,
        );
        final rows = <Map<String, dynamic>>[];
        for (final Map<String, dynamic> e in data) {
          final map = Map<String, dynamic>.from(e);
          map['__dt'] = _parseDateTime(map['created_at']);
          map['created_at'] = _formatDate(e['created_at']);
          if (map.containsKey('retorno_at')) {
            map['retorno_at'] = _formatDate(map['retorno_at']);
          } else if (_tipo == 'operador') {
            map['retorno_at'] = '';
          }
          if (map.containsKey('created_at_final')) {
            map['created_at_final'] = _formatDate(e['created_at_final']);
          }
          if (_tipo == 'operador') {
            map['evento'] = map['evento'] ?? 'amostragem';
            map['motivo'] = map['motivo'] ?? '';
          }
          rows.add(map);
        }
        rows.sort(_compareByDate);
        return _withGroupHeaders(rows);
      }
    }

    setState(() {
      _future = carregador();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: defaultPadding),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final tipoField = DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'operador',
                    child: Text('Verificação do Processo'),
                  ),
                  DropdownMenuItem(
                    value: 'preparador',
                    child: Text('Liberação/Finalização'),
                  ),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'operador'),
              );
              final modoField = DropdownButtonFormField<String>(
                value: _modo,
                decoration: const InputDecoration(
                  labelText: 'Pesquisar por',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'os', child: Text('OS')),
                  DropdownMenuItem(
                    value: 'part',
                    child: Text('Partnumber + Operação'),
                  ),
                ],
                onChanged: (v) => setState(() => _modo = v ?? 'os'),
              );
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tipoField,
                    const SizedBox(height: defaultPadding),
                    modoField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: tipoField),
                  const SizedBox(width: defaultPadding),
                  Expanded(child: modoField),
                ],
              );
            },
          ),
          const SizedBox(height: defaultPadding),
          if (_modo == 'os')
            TextField(
              controller: _osCtrl,
              decoration: const InputDecoration(
                labelText: 'Número da OS',
                border: OutlineInputBorder(),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final partField = TextField(
                  controller: _partCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Partnumber',
                    border: OutlineInputBorder(),
                  ),
                );
                final opField = TextField(
                  controller: _opCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operação',
                    border: OutlineInputBorder(),
                  ),
                );
                if (isNarrow) {
                  return Column(
                    children: [
                      partField,
                      const SizedBox(height: defaultPadding),
                      opField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: partField),
                    const SizedBox(width: defaultPadding),
                    Expanded(child: opField),
                  ],
                );
              },
            ),
          const SizedBox(height: defaultPadding),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _buscar,
              child: const Text('Buscar'),
            ),
          ),
          const SizedBox(height: defaultPadding),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (_future == null) {
                return const Text(
                  'Realize a busca para visualizar os resultados.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final dados = snapshot.data ?? [];
              if (dados.isEmpty) {
                return const Text('Nenhum dado encontrado.');
              }
              final headerMap = _headerConfigs[_tipo] ?? const {};
              _ensureColumnState(headerMap);
              final hiddenSet = _hiddenColumns[_tipo] ?? <String>{};
              final order = _columnOrders[_tipo] ?? <String>[];
              final visibleColumns = [
                for (final key in order)
                  if (!hiddenSet.contains(key)) key,
              ];
              final hiddenColumns = [
                for (final key in order)
                  if (hiddenSet.contains(key)) key,
              ];
              final manager = _buildColumnManager(
                context,
                headerMap,
                visibleColumns,
                hiddenColumns,
              );
              if (visibleColumns.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    manager,
                    const SizedBox(height: 12),
                    const Text('Selecione ao menos uma coluna para exibir.'),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  manager,
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final theme = Theme.of(context);
                      final groupColor = theme.colorScheme.surfaceVariant
                          .withOpacity(0.25);
                      final pauseColor = Colors.orange.withOpacity(0.12);
                      final firstColumnKey = visibleColumns.isNotEmpty
                          ? visibleColumns.first
                          : null;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            columns: visibleColumns
                                .map(
                                  (h) => DataColumn(
                                    label: _buildHeaderLabel(
                                      h,
                                      headerMap[h] ?? h,
                                      () => _hideColumn(h),
                                    ),
                                  ),
                                )
                                .toList(),
                            rows: dados.map((r) {
                              final isGroup = r['__isGroup'] == true;
                              final isPause = r['evento'] == 'pausa_jornada';
                              return DataRow(
                                color:
                                    MaterialStateProperty.resolveWith<Color?>((
                                      states,
                                    ) {
                                      if (isGroup) return groupColor;
                                      if (isPause) return pauseColor;
                                      return null;
                                    }),
                                cells: visibleColumns.map((h) {
                                  if (isGroup) {
                                    final text = h == firstColumnKey
                                        ? 'Horário: ${r['created_at'] ?? ''}'
                                        : '';
                                    final style = theme.textTheme.labelLarge
                                        ?.copyWith(fontWeight: FontWeight.bold);
                                    return DataCell(Text(text, style: style));
                                  }
                                  final value = r[h];
                                  final display = value == null
                                      ? ''
                                      : value.toString();
                                  return DataCell(
                                    Text(
                                      display,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
