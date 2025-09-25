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
  const _TableMetrics({
    required this.columnWidths,
    required this.totalWidth,
    required this.columnSpacing,
  });

  final List<double> columnWidths;
  final double totalWidth;
  final double columnSpacing;
}

class _FilterDialogResult {
  const _FilterDialogResult({
    this.selectedValues = const <String>{},
    this.clearFilter = false,
  });

  final Set<String> selectedValues;
  final bool clearFilter;
}

class _ColumnFilterDialog extends StatefulWidget {
  const _ColumnFilterDialog({
    required this.label,
    required this.values,
    required this.initialSelection,
    required this.describeValue,
  });

  final String label;
  final List<String> values;
  final Set<String> initialSelection;
  final String Function(String) describeValue;

  @override
  State<_ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<_ColumnFilterDialog> {
  late Set<String> _tempSelected;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final baseSelection = widget.initialSelection.isEmpty
        ? widget.values.toSet()
        : Set<String>.from(widget.initialSelection);
    baseSelection.retainAll(widget.values);
    if (baseSelection.isEmpty && widget.values.isNotEmpty) {
      _tempSelected = widget.values.toSet();
    } else {
      _tempSelected = baseSelection;
    }
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.values.isNotEmpty &&
            _tempSelected.length == widget.values.length;
    final listHeight = math.min(320.0, 36.0 * widget.values.length + 12);
    return AlertDialog(
      title: Text('Filtrar ${widget.label}'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              dense: true,
              value: allSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _tempSelected = widget.values.toSet();
                  } else {
                    _tempSelected = <String>{};
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Selecionar tudo'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 12),
            SizedBox(
              height: listHeight,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: widget.values.length > 8,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.values.length,
                  itemBuilder: (context, index) {
                    final value = widget.values[index];
                    final checked = _tempSelected.contains(value);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _tempSelected.add(value);
                          } else {
                            _tempSelected.remove(value);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(widget.describeValue(value)),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(const _FilterDialogResult(clearFilter: true));
          },
          child: const Text('Limpar filtro'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _tempSelected.isEmpty
              ? null
              : () {
            Navigator.of(context).pop(
              _FilterDialogResult(
                selectedValues: Set<String>.from(_tempSelected),
              ),
            );
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
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
  final Map<String, Map<String, double>> _columnWidthOverrides = {
    'operador': <String, double>{},
    'preparador': <String, double>{},
  };
  final Map<String, Map<String, Set<String>>> _columnFilters = {
    'operador': <String, Set<String>>{},
    'preparador': <String, Set<String>>{},
  };

  String? _activeResizeColumn;
  final ScrollController _tableScrollController = ScrollController();

  static const double _columnSpacing = 12;
  static const double _minColumnSpacing = 6;
  static const double _cellHorizontalPadding = 12;
  static const double _cellVerticalPadding = 10;
  static const double _headerRowMinHeight = 44;
  static const double _horizontalMargin = 12;
  static const double _minColumnWidth = 40;
  static const double _maxColumnWidth = 480;
  static const double _resizeHandleHitWidth = 16;

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

  String _normalizeFilterValue(dynamic value) {
    final raw = value?.toString();
    if (raw == null) return '';
    return raw.trim();
  }

  String _describeFilterValue(String value) {
    return value.isEmpty ? '(Vazio)' : value;
  }

  String _formatFilterPreview(Set<String> values) {
    if (values.isEmpty) return '';
    const maxPreview = 2;
    final sorted = values.map(_describeFilterValue).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (sorted.length <= maxPreview) {
      return sorted.join(', ');
    }
    final remaining = sorted.length - maxPreview;
    return '${sorted.take(maxPreview).join(', ')} +$remaining';
  }

  bool _isColumnFiltered(String columnKey) {
    final filters = _columnFilters[_tipo];
    if (filters == null) return false;
    final values = filters[columnKey];
    return values != null && values.isNotEmpty;
  }

  void _clearFilter(String columnKey) {
    final filters = _columnFilters[_tipo];
    if (filters == null) return;
    if (!filters.containsKey(columnKey)) return;
    setState(() {
      filters.remove(columnKey);
    });
  }

  void _clearAllFilters() {
    final filters = _columnFilters[_tipo];
    if (filters == null || filters.isEmpty) return;
    setState(() {
      filters.clear();
    });
  }

  List<Map<String, dynamic>> _applyFiltersToRows(
      List<Map<String, dynamic>> rows,
      Map<String, Set<String>> filters,
      ) {
    if (rows.isEmpty || filters.isEmpty) {
      return List<Map<String, dynamic>>.from(rows);
    }

    final normalizedFilters = <String, Set<String>>{};
    filters.forEach((key, value) {
      if (value.isNotEmpty) {
        normalizedFilters[key] = value;
      }
    });

    if (normalizedFilters.isEmpty) {
      return List<Map<String, dynamic>>.from(rows);
    }

    final result = <Map<String, dynamic>>[];
    Map<String, dynamic>? activeGroup;
    var groupRows = <Map<String, dynamic>>[];

    void flushGroup() {
      if (activeGroup != null) {
        if (groupRows.isNotEmpty) {
          result.add(activeGroup!);
          result.addAll(groupRows);
        }
        activeGroup = null;
        groupRows = <Map<String, dynamic>>[];
      }
    }

    for (final row in rows) {
      if (row['__isGroup'] == true) {
        flushGroup();
        activeGroup = row;
        continue;
      }

      var include = true;
      for (final entry in normalizedFilters.entries) {
        final normalizedValue = _normalizeFilterValue(row[entry.key]);
        if (!entry.value.contains(normalizedValue)) {
          include = false;
          break;
        }
      }

      if (!include) {
        continue;
      }

      if (activeGroup != null) {
        groupRows.add(row);
      } else {
        result.add(row);
      }
    }

    flushGroup();
    return result;
  }

  List<Map<String, dynamic>> _applyActiveFilters(
      List<Map<String, dynamic>> rows,
      ) {
    final filters = _columnFilters[_tipo];
    if (filters == null || filters.isEmpty) {
      return List<Map<String, dynamic>>.from(rows);
    }
    return _applyFiltersToRows(rows, filters);
  }

  Future<void> _showColumnFilterSheet(
      BuildContext context,
      String columnKey,
      String label,
      List<Map<String, dynamic>> sourceRows,
      ) async {
    final filters = _columnFilters[_tipo]!;
    final otherFilters = <String, Set<String>>{};
    filters.forEach((key, value) {
      if (key == columnKey || value.isEmpty) return;
      otherFilters[key] = value;
    });

    final rowsForValues = _applyFiltersToRows(sourceRows, otherFilters);
    final values = <String>{};
    for (final row in rowsForValues) {
      if (row['__isGroup'] == true) {
        continue;
      }
      values.add(_normalizeFilterValue(row[columnKey]));
    }

    if (values.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nenhum valor disponível para filtrar em $label.'),
        ),
      );
      return;
    }

    final sortedValues = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final currentSelection = filters[columnKey];
    final initialSelection =
    (currentSelection == null || currentSelection.isEmpty)
        ? sortedValues.toSet()
        : currentSelection.where(values.contains).toSet();

    final result = await showDialog<_FilterDialogResult>(
      context: context,
      builder: (context) {
        return _ColumnFilterDialog(
          label: label,
          values: sortedValues,
          initialSelection: initialSelection,
          describeValue: _describeFilterValue,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (result.clearFilter ||
          result.selectedValues.isEmpty ||
          result.selectedValues.length == sortedValues.length) {
        filters.remove(columnKey);
      } else {
        filters[columnKey] = Set<String>.from(result.selectedValues);
      }
    });
  }

  @override
  void dispose() {
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _ensureColumnState(Map<String, String> headerMap) {
    final allowedKeys = headerMap.keys.toList(growable: false);
    final allowedSet = allowedKeys.toSet();
    final order = _columnOrders.putIfAbsent(_tipo, () => <String>[]);
    final hidden = _hiddenColumns.putIfAbsent(_tipo, () => <String>{});
    final overrides = _columnWidthOverrides.putIfAbsent(
      _tipo,
          () => <String, double>{},
    );
    final filters = _columnFilters.putIfAbsent(
      _tipo,
          () => <String, Set<String>>{},
    );
    order.removeWhere((key) => !allowedSet.contains(key));
    hidden.removeWhere((key) => !allowedSet.contains(key));
    overrides.removeWhere((key, _) => !allowedSet.contains(key));
    filters.removeWhere((key, _) => !allowedSet.contains(key));
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

  void _setColumnWidthOverride(String columnKey, double width) {
    final overrides = _columnWidthOverrides[_tipo];
    if (overrides == null) {
      return;
    }
    final clamped = width.clamp(_minColumnWidth, _maxColumnWidth).toDouble();
    final previous = overrides[columnKey];
    if (previous != null && (previous - clamped).abs() <= 0.1) {
      return;
    }
    setState(() {
      overrides[columnKey] = clamped;
    });
  }

  void _removeColumnWidthOverride(String columnKey) {
    final overrides = _columnWidthOverrides[_tipo];
    if (overrides == null) {
      return;
    }
    if (!overrides.containsKey(columnKey)) {
      if (_activeResizeColumn == columnKey) {
        setState(() {
          _activeResizeColumn = null;
        });
      }
      return;
    }
    setState(() {
      overrides.remove(columnKey);
      if (_activeResizeColumn == columnKey) {
        _activeResizeColumn = null;
      }
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

    final spacingCount = math.max(0, visibleColumns.length - 1);
    final spacing = _columnSpacing * spacingCount;
    final totalWidth = widths.fold<double>(
      spacing,
          (value, element) => value + element,
    );
    final appliedSpacing = spacingCount == 0 ? 0.0 : _columnSpacing;
    return _TableMetrics(
      columnWidths: widths,
      totalWidth: totalWidth,
      columnSpacing: appliedSpacing,
    );
  }

  List<int> _buildColumnFlexes(List<double> widths) {
    if (widths.isEmpty) {
      return const <int>[];
    }
    final positiveWidths = widths.map((width) => math.max(0.0, width)).toList();
    final total = positiveWidths.fold<double>(0, (sum, width) => sum + width);
    if (total <= 0) {
      return List<int>.filled(widths.length, 1);
    }
    final scale = 1000 / total;
    final flexes = <int>[];
    for (final width in positiveWidths) {
      final flex = math.max(1, (width * scale).round());
      flexes.add(flex);
    }
    final sumFlex = flexes.fold<int>(0, (sum, value) => sum + value);
    if (sumFlex <= 0) {
      return List<int>.filled(widths.length, 1);
    }
    return flexes;
  }

  _TableMetrics _fitColumnsToViewport(
      _TableMetrics metrics,
      int columnCount,
      double viewportWidth, {
        Set<int> lockedColumns = const <int>{},
      }) {
    if (columnCount <= 0 || metrics.columnWidths.isEmpty) {
      return _TableMetrics(
        columnWidths: List<double>.from(metrics.columnWidths),
        totalWidth: metrics.totalWidth,
        columnSpacing: metrics.columnSpacing,
      );
    }

    final spacingCount = math.max(0, columnCount - 1);
    final adjusted = List<double>.from(metrics.columnWidths);
    final baseSpacing = spacingCount == 0 ? 0.0 : metrics.columnSpacing;
    var spacingWidth = baseSpacing * spacingCount;
    var contentWidth = adjusted.fold<double>(0, (sum, width) => sum + width);
    var totalWidth = contentWidth + spacingWidth;

    if (!viewportWidth.isFinite || viewportWidth <= 0) {
      final spacingValue = spacingCount == 0 ? 0.0 : baseSpacing;
      return _TableMetrics(
        columnWidths: adjusted,
        totalWidth: totalWidth,
        columnSpacing: spacingValue,
      );
    }

    final minSpacingWidth = spacingCount * _minColumnSpacing;
    final minContentWidth = columnCount * _minColumnWidth;
    final absoluteMinTotalWidth = minContentWidth + minSpacingWidth;
    final targetTotalWidth = math.max(viewportWidth, absoluteMinTotalWidth);
    var remainingReduction = totalWidth - targetTotalWidth;

    if (remainingReduction <= 0) {
      final spacingValue = spacingCount == 0 ? 0.0 : baseSpacing;
      return _TableMetrics(
        columnWidths: adjusted,
        totalWidth: totalWidth,
        columnSpacing: spacingValue,
      );
    }

    if (spacingCount > 0 && spacingWidth > minSpacingWidth) {
      final spacingReduction = math.min(
        remainingReduction,
        spacingWidth - minSpacingWidth,
      );
      if (spacingReduction > 0) {
        spacingWidth -= spacingReduction;
        remainingReduction -= spacingReduction;
      }
    }

    const double tolerance = 0.1;
    if (remainingReduction > tolerance) {
      while (remainingReduction > tolerance) {
        double adjustableSum = 0;
        for (var i = 0; i < adjusted.length; i++) {
          if (lockedColumns.contains(i)) {
            continue;
          }
          final available = adjusted[i] - _minColumnWidth;
          if (available > 0) {
            adjustableSum += available;
          }
        }
        if (adjustableSum <= tolerance) {
          break;
        }

        var reducedThisPass = 0.0;
        for (var i = 0; i < adjusted.length; i++) {
          if (lockedColumns.contains(i)) {
            continue;
          }
          final available = adjusted[i] - _minColumnWidth;
          if (available <= 0) continue;
          final share = remainingReduction * (available / adjustableSum);
          final reduction = math.min(available, share);
          if (reduction <= 0) continue;
          adjusted[i] -= reduction;
          reducedThisPass += reduction;
        }

        if (reducedThisPass <= tolerance) {
          break;
        }
        remainingReduction -= reducedThisPass;
      }
    }

    contentWidth = adjusted.fold<double>(0, (sum, width) => sum + width);
    final spacingValue = spacingCount == 0
        ? 0.0
        : math.max(_minColumnSpacing, spacingWidth / spacingCount);
    final adjustedSpacingWidth = spacingCount * spacingValue;
    totalWidth = contentWidth + adjustedSpacingWidth;
    return _TableMetrics(
      columnWidths: adjusted,
      totalWidth: totalWidth,
      columnSpacing: spacingValue,
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
      BuildContext context,
      String columnKey,
      String label,
      VoidCallback onHide,
      VoidCallback onFilter,
      bool filterActive,
      ) {
    final theme = Theme.of(context);
    final iconColor = filterActive
        ? theme.colorScheme.primary
        : theme.iconTheme.color?.withOpacity(0.7) ?? theme.hintColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        if (!contentWidth.isFinite || contentWidth <= 0) {
          return const SizedBox.shrink();
        }
        var iconTapSize = contentWidth >= 72
            ? 32.0
            : contentWidth >= 54
            ? 28.0
            : contentWidth >= 40
            ? 24.0
            : contentWidth >= 30
            ? 20.0
            : contentWidth * 0.7;
        final minTapSize = math.min(18.0, contentWidth);
        iconTapSize = iconTapSize.clamp(minTapSize, contentWidth);
        final availableForLabel = math.max(0.0, contentWidth - iconTapSize);
        final startPadding = math.min(
          _cellHorizontalPadding,
          math.max(2.0, availableForLabel * 0.35),
        );
        final gap = math.max(2.0, math.min(6.0, startPadding));
        var endPadding = iconTapSize + gap;
        final maxEndPadding = math.max(0.0, contentWidth - startPadding);
        if (endPadding > maxEndPadding) {
          endPadding = maxEndPadding;
        }
        final labelPadding = EdgeInsetsDirectional.only(
          start: startPadding,
          end: endPadding,
          top: _cellVerticalPadding,
          bottom: _cellVerticalPadding,
        );
        final iconPadding = EdgeInsetsDirectional.only(
          end: math.max(2.0, math.min(startPadding, _cellHorizontalPadding)),
          top: _cellVerticalPadding,
          bottom: _cellVerticalPadding,
        );

        final resolvedHeight =
        constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : _headerRowMinHeight;
        return SizedBox(
          width: contentWidth,
          height: resolvedHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: labelPadding,
                  child: Tooltip(
                    message: 'Toque para ocultar',
                    child: InkWell(
                      onTap: onHide,
                      borderRadius: BorderRadius.circular(6),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: iconPadding,
                  child: Tooltip(
                    message: filterActive ? 'Editar filtro' : 'Filtrar coluna',
                    child: SizedBox(
                      width: iconTapSize,
                      height: iconTapSize,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onFilter,
                          borderRadius: BorderRadius.circular(iconTapSize / 2),
                          child: Center(
                            child: Icon(
                              filterActive
                                  ? Icons.filter_alt
                                  : Icons.filter_alt_outlined,
                              size: iconTapSize <= 20 ? 14 : 16,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResizeHandle(
      BuildContext context,
      String columnKey,
      double currentWidth,
      ) {
    final theme = Theme.of(context);
    final isActive = _activeResizeColumn == columnKey;
    final indicatorColor = isActive
        ? theme.colorScheme.primary
        : theme.dividerColor.withOpacity(0.6);
    final overrides = _columnWidthOverrides[_tipo];
    return Tooltip(
      message:
      'Arraste para redimensionar. Toque duas vezes para restaurar o tamanho automático.',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            if (_activeResizeColumn != columnKey) {
              setState(() {
                _activeResizeColumn = columnKey;
              });
            }
          },
          onHorizontalDragUpdate: (details) {
            final baseWidth = overrides?[columnKey] ?? currentWidth;
            final nextWidth = (baseWidth + details.delta.dx).clamp(
              _minColumnWidth,
              _maxColumnWidth,
            );
            _setColumnWidthOverride(columnKey, nextWidth.toDouble());
          },
          onHorizontalDragEnd: (_) {
            if (_activeResizeColumn == columnKey) {
              setState(() {
                _activeResizeColumn = null;
              });
            }
          },
          onHorizontalDragCancel: () {
            if (_activeResizeColumn == columnKey) {
              setState(() {
                _activeResizeColumn = null;
              });
            }
          },
          onDoubleTap: () {
            _removeColumnWidthOverride(columnKey);
          },
          child: SizedBox(
            width: _resizeHandleHitWidth,
            child: Center(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
          'Toque para ocultar e arraste os chips, soltando nas áreas destacadas para reordenar. Arraste os divisores no cabeçalho para ajustar a largura das colunas. Use o ícone de filtro no cabeçalho para filtrar os valores.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget? _buildActiveFilterSummary(
      BuildContext context,
      Map<String, String> headerMap,
      List<Map<String, dynamic>> sourceRows,
      ) {
    final filters = _columnFilters[_tipo];
    if (filters == null || filters.isEmpty) {
      return null;
    }
    final chips = <Widget>[];
    filters.forEach((columnKey, values) {
      if (values.isEmpty) return;
      final label = headerMap[columnKey] ?? columnKey;
      final preview = _formatFilterPreview(values);
      chips.add(
        InputChip(
          avatar: const Icon(Icons.filter_alt, size: 18),
          label: Text('$label: $preview'),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () =>
              _showColumnFilterSheet(context, columnKey, label, sourceRows),
          onDeleted: () => _clearFilter(columnKey),
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    });

    if (chips.isEmpty) {
      return null;
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filtros ativos', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Limpar filtros'),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow(
      BuildContext context,
      Map<String, String> headerMap,
      List<String> visibleColumns,
      List<double> columnWidths,
      List<int> columnFlexes,
      double totalWidth,
      double columnSpacing,
      List<Map<String, dynamic>> sourceRows,
      ) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.4,
    );
    final borderColor = theme.dividerColor.withOpacity(0.18);
    final spacingCount = math.max(0, visibleColumns.length - 1);
    final totalSpacing = spacingCount * columnSpacing;
    final resolvedWidths = List<double>.from(columnWidths);
    final flexes = columnFlexes.isEmpty
        ? _buildColumnFlexes(resolvedWidths)
        : columnFlexes;

    final cells = <Widget>[];
    for (var index = 0; index < visibleColumns.length; index++) {
      final columnKey = visibleColumns[index];
      final fallbackWidth = resolvedWidths[index];
      final flex = index < flexes.length ? math.max(1, flexes[index]) : 1;
      cells.add(
        Flexible(
          fit: FlexFit.tight,
          flex: flex,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: _minColumnWidth),
            child: SizedBox(
              height: _headerRowMinHeight,
              child: LayoutBuilder(
                builder: (context, cellConstraints) {
                  final maxWidth = cellConstraints.maxWidth.isFinite
                      ? cellConstraints.maxWidth
                      : math.max(_minColumnWidth, fallbackWidth);
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: _cellHorizontalPadding,
                          end:
                          _cellHorizontalPadding + _resizeHandleHitWidth,
                        ),
                        child: _buildHeaderLabel(
                          context,
                          columnKey,
                          headerMap[columnKey] ?? columnKey,
                              () => _hideColumn(columnKey),
                              () => _showColumnFilterSheet(
                            context,
                            columnKey,
                            headerMap[columnKey] ?? columnKey,
                            sourceRows,
                          ),
                          _isColumnFiltered(columnKey),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child:
                        _buildResizeHandle(context, columnKey, maxWidth),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      if (index != visibleColumns.length - 1) {
        cells.add(SizedBox(width: math.max(0, columnSpacing)));
      }
    }

    final effectiveWidth = math.max(
      totalWidth,
      resolvedWidths.fold<double>(0, (sum, width) => sum + width) + totalSpacing,
    );
    final contentRow = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: cells,
    );
    return Container(
      width: effectiveWidth,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: effectiveWidth,
          child: contentRow,
        ),
      ),
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
      List<int> columnFlexes,
      double totalWidth,
      double columnSpacing,
      Color pauseColor,
      ) {
    final theme = Theme.of(context);
    final isPause = row['evento'] == 'pausa_jornada';
    final background = isPause ? pauseColor : null;
    final spacingCount = math.max(0, visibleColumns.length - 1);
    final totalSpacing = spacingCount * columnSpacing;
    final flexes = columnFlexes.isEmpty
        ? _buildColumnFlexes(columnWidths)
        : columnFlexes;

    final cells = <Widget>[];
    for (var index = 0; index < visibleColumns.length; index++) {
      final columnKey = visibleColumns[index];
      final flex = index < flexes.length ? math.max(1, flexes[index]) : 1;
      final value = row[columnKey];
      final text = value == null ? '' : value.toString();
      cells.add(
        Flexible(
          fit: FlexFit.tight,
          flex: flex,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: _minColumnWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _cellHorizontalPadding,
                vertical: _cellVerticalPadding,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      );
      if (index != visibleColumns.length - 1) {
        cells.add(SizedBox(width: math.max(0, columnSpacing)));
      }
    }

    final effectiveWidth = math.max(
      totalWidth,
      columnWidths.fold<double>(0, (sum, width) => sum + width) + totalSpacing,
    );
    final contentRow = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: cells,
    );
    return Container(
      width: effectiveWidth,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: SizedBox(
        width: effectiveWidth,
        child: contentRow,
      ),
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
              final filterSummary = _buildActiveFilterSummary(
                context,
                headerMap,
                dados,
              );
              final filteredRows = _applyActiveFilters(dados);
              if (visibleColumns.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    manager,
                    if (filterSummary != null) ...[
                      const SizedBox(height: 12),
                      filterSummary,
                    ],
                    const SizedBox(height: 12),
                    const Text('Selecione ao menos uma coluna para exibir.'),
                  ],
                );
              }
              if (filteredRows.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    manager,
                    if (filterSummary != null) ...[
                      const SizedBox(height: 12),
                      filterSummary,
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum resultado com os filtros aplicados.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  manager,
                  if (filterSummary != null) ...[
                    const SizedBox(height: 12),
                    filterSummary,
                  ],
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
                        filteredRows,
                      );
                      final overrides =
                          _columnWidthOverrides[_tipo] ??
                              const <String, double>{};
                      final lockedIndices = <int>{};
                      final overrideAdjusted = List<double>.from(
                        metrics.columnWidths,
                      );
                      double overrideContentWidth = 0;
                      for (var i = 0; i < overrideAdjusted.length; i++) {
                        final overrideWidth = overrides[visibleColumns[i]];
                        if (overrideWidth != null) {
                          final clamped = overrideWidth
                              .clamp(_minColumnWidth, _maxColumnWidth)
                              .toDouble();
                          overrideAdjusted[i] = clamped;
                          lockedIndices.add(i);
                        }
                        overrideContentWidth += overrideAdjusted[i];
                      }
                      final spacingCount = math.max(
                        0,
                        visibleColumns.length - 1,
                      );
                      final baseSpacing = spacingCount == 0
                          ? 0.0
                          : metrics.columnSpacing;
                      final manualSpacingWidth = baseSpacing * spacingCount;
                      final manualMetrics = _TableMetrics(
                        columnWidths: overrideAdjusted,
                        totalWidth: overrideContentWidth + manualSpacingWidth,
                        columnSpacing: baseSpacing,
                      );
                      final mediaWidth = MediaQuery.maybeOf(
                        context,
                      )?.size.width;
                      final rawViewportWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : (mediaWidth ?? manualMetrics.totalWidth);
                      final availableViewportWidth = rawViewportWidth.isFinite
                          ? math.max(
                        0.0,
                        rawViewportWidth - (_horizontalMargin * 2),
                      )
                          : rawViewportWidth;
                      final fittedMetrics = _fitColumnsToViewport(
                        manualMetrics,
                        visibleColumns.length,
                        availableViewportWidth,
                        lockedColumns: lockedIndices,
                      );
                      final adjustedColumns = fittedMetrics.columnWidths;
                      final columnFlexes = _buildColumnFlexes(adjustedColumns);
                      final columnSpacing = spacingCount == 0
                          ? 0.0
                          : fittedMetrics.columnSpacing;
                      final spacingWidth = columnSpacing * spacingCount;
                      final naturalTableWidth = adjustedColumns.fold<double>(
                        spacingWidth,
                            (sum, width) => sum + width,
                      );
                      final viewportBaseline = availableViewportWidth.isFinite
                          ? availableViewportWidth
                          : naturalTableWidth;
                      final tableWidth = math.max(
                        naturalTableWidth,
                        viewportBaseline,
                      );
                      final rows = <Widget>[
                        _buildTableHeaderRow(
                          context,
                          headerMap,
                          visibleColumns,
                          adjustedColumns,
                          columnFlexes,
                          tableWidth,
                          columnSpacing,
                          dados,
                        ),
                        const SizedBox(height: 8),
                      ];
                      for (final row in filteredRows) {
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
                              columnFlexes,
                              tableWidth,
                              columnSpacing,
                              pauseColor,
                            ),
                          );
                        }
                      }
                      final needsHorizontalScroll =
                          naturalTableWidth - viewportBaseline > 0.5;
                      final tableView = SingleChildScrollView(
                        controller: _tableScrollController,
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
                      return Scrollbar(
                        controller: _tableScrollController,
                        thumbVisibility: needsHorizontalScroll,
                        trackVisibility: needsHorizontalScroll,
                        notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                        child: tableView,
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