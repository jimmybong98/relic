import 'dart:math' as math;

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

class _TableMetrics {
  const _TableMetrics({required this.columnWidths, required this.totalWidth});

  final List<double> columnWidths;
  final double totalWidth;
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

  static const double _columnSpacing = 12;
  static const double _cellHorizontalPadding = 12;
  static const double _cellVerticalPadding = 10;
  static const double _horizontalMargin = 12;
  static const double _minColumnWidth = 56;
  static const double _maxColumnWidth = 320;

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

  void _reorderVisibleColumn(String columnKey, int dropIndex) {
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
    if (dropIndex < 0 || dropIndex > visible.length) {
      return;
    }
    var adjustedIndex = dropIndex;
    if (adjustedIndex == oldIndex || adjustedIndex == oldIndex + 1) {
      return;
    }
    final working = List<String>.from(visible);
    final moved = working.removeAt(oldIndex);
    if (adjustedIndex > oldIndex) {
      adjustedIndex -= 1;
    }
    working.insert(adjustedIndex, moved);
    final hiddenOrder = [
      for (final key in order)
        if (hidden.contains(key)) key,
    ];
    setState(() {
      order
        ..clear()
        ..addAll(working)
        ..addAll(hiddenOrder);
    });
  }

  _TableMetrics _computeTableMetrics(
    BuildContext context,
    Map<String, String> headerMap,
    List<String> visibleColumns,
    List<Map<String, dynamic>> rows,
  ) {
    final direction = Directionality.of(context);
    final theme = Theme.of(context);
    final headerStyle =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    const dataStyle = TextStyle(fontSize: 12);
    final painter = TextPainter(
      textDirection: direction,
      maxLines: 1,
      ellipsis: '…',
    );

    double measure(String text, TextStyle style) {
      if (text.isEmpty) {
        return 0;
      }
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout(maxWidth: double.infinity);
      return painter.width;
    }

    final widths = <double>[];
    for (final columnKey in visibleColumns) {
      double maxWidth = 0;
      maxWidth = math.max(
        maxWidth,
        measure(headerMap[columnKey] ?? columnKey, headerStyle),
      );
      for (final row in rows) {
        if (row['__isGroup'] == true) {
          continue;
        }
        final value = row[columnKey];
        if (value == null) {
          continue;
        }
        maxWidth = math.max(maxWidth, measure(value.toString(), dataStyle));
      }
      final padded = maxWidth + (_cellHorizontalPadding * 2);
      final width = padded.clamp(_minColumnWidth, _maxColumnWidth).toDouble();
      widths.add(width);
    }

    final spacing = _columnSpacing * math.max(0, visibleColumns.length - 1);
    final totalWidth = widths.fold<double>(
      spacing,
      (value, element) => value + element,
    );
    return _TableMetrics(columnWidths: widths, totalWidth: totalWidth);
  }

  _TableMetrics _fitColumnsToViewport(
    _TableMetrics metrics,
    int columnCount,
    double viewportWidth,
  ) {
    if (columnCount <= 0 || metrics.columnWidths.isEmpty) {
      return const _TableMetrics(columnWidths: <double>[], totalWidth: 0);
    }

    final spacing = _columnSpacing * math.max(0, columnCount - 1);
    final adjusted = List<double>.from(metrics.columnWidths);
    final contentWidth = adjusted.fold<double>(0, (sum, width) => sum + width);
    final baseTotalWidth = contentWidth + spacing;

    if (!viewportWidth.isFinite || viewportWidth <= 0) {
      return _TableMetrics(columnWidths: adjusted, totalWidth: baseTotalWidth);
    }

    final minContentWidth = columnCount * _minColumnWidth;
    final minTotalWidth = minContentWidth + spacing;

    if (baseTotalWidth <= viewportWidth) {
      if (adjusted.isNotEmpty) {
        adjusted[adjusted.length - 1] += viewportWidth - baseTotalWidth;
      }
      return _TableMetrics(columnWidths: adjusted, totalWidth: viewportWidth);
    }

    final targetTotalWidth = math.max(viewportWidth, minTotalWidth);
    final targetContentWidth = targetTotalWidth - spacing;
    var remainingReduction = contentWidth - targetContentWidth;

    if (remainingReduction <= 0) {
      if (adjusted.isNotEmpty) {
        adjusted[adjusted.length - 1] += targetContentWidth - contentWidth;
      }
      final newContent = adjusted.fold<double>(0, (sum, width) => sum + width);
      return _TableMetrics(
        columnWidths: adjusted,
        totalWidth: newContent + spacing,
      );
    }

    const double tolerance = 0.1;
    while (remainingReduction > tolerance) {
      double adjustableSum = 0;
      for (final width in adjusted) {
        final available = width - _minColumnWidth;
        if (available > 0) {
          adjustableSum += available;
        }
      }
      if (adjustableSum <= 0) {
        final actualContent = adjusted.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        return _TableMetrics(
          columnWidths: adjusted,
          totalWidth: actualContent + spacing,
        );
      }

      var reducedThisPass = 0.0;
      for (var i = 0; i < adjusted.length; i++) {
        final available = adjusted[i] - _minColumnWidth;
        if (available <= 0) continue;
        final share = remainingReduction * (available / adjustableSum);
        final reduction = math.min(available, share);
        if (reduction <= 0) continue;
        adjusted[i] -= reduction;
        reducedThisPass += reduction;
      }

      if (reducedThisPass <= 0) {
        break;
      }
      remainingReduction -= reducedThisPass;
    }

    final adjustedContentWidth = adjusted.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final diff = targetContentWidth - adjustedContentWidth;
    if (diff > tolerance && adjusted.isNotEmpty) {
      adjusted[adjusted.length - 1] += diff;
    }

    final finalContentWidth = adjusted.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    return _TableMetrics(
      columnWidths: adjusted,
      totalWidth: finalContentWidth + spacing,
    );
  }

  Widget _buildColumnChip(
    BuildContext context,
    String columnKey,
    String label, {
    VoidCallback? onPressed,
    bool enableTooltip = true,
    bool showDelete = true,
  }) {
    final chip = InputChip(
      avatar: const Icon(Icons.drag_indicator, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onPressed,
      onDeleted: showDelete ? onPressed : null,
      deleteIcon: showDelete
          ? const Icon(Icons.visibility_off_outlined, size: 18)
          : null,
      deleteButtonTooltipMessage: showDelete ? 'Ocultar coluna' : null,
    );
    if (!enableTooltip) {
      return chip;
    }
    final message = showDelete
        ? 'Toque para ocultar ou arraste para reordenar'
        : 'Arraste para reordenar';
    return Tooltip(message: message, child: chip);
  }

  Widget _buildReorderableChip(
    BuildContext context,
    Map<String, String> headerMap,
    String columnKey,
  ) {
    final label = headerMap[columnKey] ?? columnKey;
    Widget wrapPointer(Widget child) {
      return MouseRegion(cursor: SystemMouseCursors.grab, child: child);
    }

    return Draggable<String>(
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
          showDelete: false,
        ),
      ),
      childWhenDragging: wrapPointer(
        Opacity(
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
      ),
      child: wrapPointer(
        _buildColumnChip(
          context,
          columnKey,
          label,
          onPressed: () => _hideColumn(columnKey),
        ),
      ),
    );
  }

  Widget _buildInsertionTarget(BuildContext context, int index) {
    final theme = Theme.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final order = _columnOrders[_tipo];
        if (order == null || !order.contains(details.data)) {
          return false;
        }
        final hidden = _hiddenColumns[_tipo];
        if (hidden != null && hidden.contains(details.data)) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        _reorderVisibleColumn(details.data, index);
      },
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 14,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.08,
                  ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
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
    return Tooltip(
      message: 'Toque para ocultar',
      child: InkWell(
        onTap: onHide,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
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
              const SizedBox(width: 4),
              const Icon(Icons.visibility_off_outlined, size: 16),
            ],
          ),
        ),
      ),
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
          const SizedBox(height: 12),
        ],
        Text('Colunas visíveis', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < visibleColumns.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInsertionTarget(context, i),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: KeyedSubtree(
                      key: ValueKey('visible_${visibleColumns[i]}'),
                      child: _buildReorderableChip(
                        context,
                        headerMap,
                        visibleColumns[i],
                      ),
                    ),
                  ),
                ],
              ),
            if (visibleColumns.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInsertionTarget(context, visibleColumns.length),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Toque para ocultar e arraste os chips, soltando nas áreas destacadas para reordenar.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow(
    BuildContext context,
    Map<String, String> headerMap,
    List<String> visibleColumns,
    List<double> columnWidths,
    double totalWidth,
  ) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.4,
    );
    final borderColor = theme.dividerColor.withOpacity(0.18);
    final cells = <Widget>[];
    for (var index = 0; index < visibleColumns.length; index++) {
      final columnKey = visibleColumns[index];
      cells.add(
        Container(
          width: columnWidths[index],
          padding: const EdgeInsets.symmetric(
            horizontal: _cellHorizontalPadding,
            vertical: _cellVerticalPadding,
          ),
          alignment: Alignment.centerLeft,
          child: _buildHeaderLabel(
            columnKey,
            headerMap[columnKey] ?? columnKey,
            () => _hideColumn(columnKey),
          ),
        ),
      );
      if (index != visibleColumns.length - 1) {
        cells.add(const SizedBox(width: _columnSpacing));
      }
    }
    return Container(
      width: totalWidth,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: cells),
    );
  }

  Widget _buildGroupHeaderRow(
    BuildContext context,
    Map<String, dynamic> row,
    double totalWidth,
    Color groupColor,
  ) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final createdAt = row['created_at']?.toString() ?? '';
    final text = createdAt.isEmpty ? 'Horário' : 'Horário: $createdAt';
    return Container(
      width: totalWidth,
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: _cellHorizontalPadding,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: groupColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: textStyle),
    );
  }

  Widget _buildDataRowWidget(
    BuildContext context,
    Map<String, dynamic> row,
    List<String> visibleColumns,
    List<double> columnWidths,
    double totalWidth,
    Color pauseColor,
  ) {
    final theme = Theme.of(context);
    final isPause = row['evento'] == 'pausa_jornada';
    final background = isPause ? pauseColor : null;
    final cells = <Widget>[];
    for (var index = 0; index < visibleColumns.length; index++) {
      final columnKey = visibleColumns[index];
      final value = row[columnKey];
      final text = value == null ? '' : value.toString();
      cells.add(
        Container(
          width: columnWidths[index],
          padding: const EdgeInsets.symmetric(
            horizontal: _cellHorizontalPadding,
            vertical: _cellVerticalPadding,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );
      if (index != visibleColumns.length - 1) {
        cells.add(const SizedBox(width: _columnSpacing));
      }
    }
    return Container(
      width: totalWidth,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: cells),
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
                      final metrics = _computeTableMetrics(
                        context,
                        headerMap,
                        visibleColumns,
                        dados,
                      );
                      final mediaWidth = MediaQuery.maybeOf(
                        context,
                      )?.size.width;
                      final rawViewportWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : (mediaWidth ?? metrics.totalWidth);
                      final availableViewportWidth = rawViewportWidth.isFinite
                          ? math.max(
                              0.0,
                              rawViewportWidth - (_horizontalMargin * 2),
                            )
                          : rawViewportWidth;
                      final fittedMetrics = _fitColumnsToViewport(
                        metrics,
                        visibleColumns.length,
                        availableViewportWidth,
                      );
                      final adjustedColumns = fittedMetrics.columnWidths;
                      final tableWidth = fittedMetrics.totalWidth;
                      final rows = <Widget>[
                        _buildTableHeaderRow(
                          context,
                          headerMap,
                          visibleColumns,
                          adjustedColumns,
                          tableWidth,
                        ),
                        const SizedBox(height: 8),
                      ];
                      for (final row in dados) {
                        if (row['__isGroup'] == true) {
                          rows.add(
                            _buildGroupHeaderRow(
                              context,
                              row,
                              tableWidth,
                              groupColor,
                            ),
                          );
                        } else {
                          rows.add(
                            _buildDataRowWidget(
                              context,
                              row,
                              visibleColumns,
                              adjustedColumns,
                              tableWidth,
                              pauseColor,
                            ),
                          );
                        }
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _horizontalMargin,
                          ),
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: rows,
                            ),
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
