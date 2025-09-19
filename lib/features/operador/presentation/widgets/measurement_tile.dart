import 'package:flutter/material.dart';

import 'package:admin/features/preparacao/data/models.dart';

class MeasurementTile extends StatefulWidget {
  final int index;
  final MedidaItem item;
  final void Function(StatusMedida status, String? medicao) onSelect;
  final bool manualEntry;

  const MeasurementTile({
    super.key,
    required this.index,
    required this.item,
    required this.onSelect,
    this.manualEntry = false,
  });

  @override
  State<MeasurementTile> createState() => _MeasurementTileState();
}

class _MeasurementTileState extends State<MeasurementTile> {
  TextEditingController? _manualCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.manualEntry) {
      _manualCtrl = TextEditingController(text: widget.item.medicao ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant MeasurementTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manualEntry) {
      _manualCtrl ??= TextEditingController();
      final newText = widget.item.medicao ?? '';
      if (oldWidget.item.medicao != widget.item.medicao &&
          _manualCtrl!.text != newText) {
        _manualCtrl!.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
          composing: TextRange.empty,
        );
      }
    } else if (_manualCtrl != null) {
      _manualCtrl!.dispose();
      _manualCtrl = null;
    }
  }

  @override
  void dispose() {
    _manualCtrl?.dispose();
    super.dispose();
  }

  String _norm(String? s) => (s ?? '').trim();

  String _nfd(String s) {
    const rep = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
      'Á': 'A',
      'À': 'A',
      'Ã': 'A',
      'Â': 'A',
      'É': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ú': 'U',
      'Ç': 'C',
    };
    var t = s;
    rep.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  bool _containsAny(String hay, List<String> needles) {
    final h = _nfd(hay.toLowerCase());
    return needles.any((n) => h.contains(_nfd(n.toLowerCase())));
  }

  bool _isVisualRugParalelismoOrAfins(MedidaItem item) {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, [
          'visual',
          'rug',
          'paralelismo',
          'anel de rosca passa',
          'cqf',
          'simetria',
          'concentricidade',
        ]) ||
        _containsAny(inst, [
          'visual',
          'rug',
          'rugosimetro',
          'paralelismo',
          'anel de rosca passa',
          'cqf',
          'simetria',
        ]);
  }

  bool _isTampao(MedidaItem item) {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, ['tamp', 'tampao', 'tampão', 'tampa']) ||
        _containsAny(inst, ['tamp', 'tampao', 'tampão', 'tampa']);
  }

  Set<String> _partsFromMedicao(String? medicao) => (medicao ?? '')
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  String _joinParts(Set<String> parts) => parts.join(' | ');

  StatusMedida _statusFromParts(Set<String> parts) {
    final hasPassa = parts.any((p) => p.startsWith('Lado passa'));
    final hasNaoPassa = parts.any((p) => p.startsWith('Lado não passa'));
    if (hasPassa && hasNaoPassa) {
      final passaReprovado = parts.contains('Lado passa — Reprovado');
      final naoPassaReprovado = parts.contains('Lado não passa — Reprovado');
      if (passaReprovado && naoPassaReprovado) {
        return StatusMedida.reprovadaAcima;
      }
      if (passaReprovado) return StatusMedida.reprovadaAbaixo;
      if (naoPassaReprovado) return StatusMedida.reprovadaAcima;
      return StatusMedida.ok;
    }
    return StatusMedida.pendente;
  }

  double? _toDoubleNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.').trim());
  }

  Color _fgOn(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : Colors.black87;

  Widget _pill({
    required String text,
    required Color bg,
    required Color border,
    bool selected = false,
    Color? fg,
    VoidCallback? onTap,
  }) {
    final fgColor = fg ?? _fgOn(bg);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? border.withValues(alpha: 0.9) : border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w600, color: fgColor),
        ),
      ),
    );
  }

  String _subtitleFor(MedidaItem item) {
    if (item.faixaTexto.isNotEmpty) return item.faixaTexto;
    final min = item.minimo;
    final max = item.maximo;
    final uni = (item.unidade ?? '').isNotEmpty ? ' ${item.unidade}' : '';
    if (min != null && max != null) {
      return '${min.toStringAsFixed(2)} – ${max.toStringAsFixed(2)}$uni';
    }
    if (min != null) {
      return '≥ ${min.toStringAsFixed(2)}$uni';
    }
    if (max != null) {
      return '≤ ${max.toStringAsFixed(2)}$uni';
    }
    return '';
  }

  double? _parseManualValue(String txt) {
    final normalized = txt.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Color _statusColor(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return Colors.green.shade600;
      case StatusMedida.reprovadaAbaixo:
      case StatusMedida.reprovadaAcima:
        return Colors.red.shade400;
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return Colors.amber.shade700;
      case StatusMedida.pendente:
        return Colors.grey;
    }
  }

  String _statusHelper(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return 'Dentro da tolerância';
      case StatusMedida.reprovadaAbaixo:
        return 'Abaixo do mínimo';
      case StatusMedida.reprovadaAcima:
        return 'Acima do máximo';
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return 'Fora da faixa ideal';
      case StatusMedida.pendente:
        return 'Preencha o valor para classificar';
    }
  }

  Widget _buildManualEntry(BuildContext context) {
    final item = widget.item;
    final ctrl = _manualCtrl ??= TextEditingController(
      text: item.medicao ?? '',
    );
    final valor = _parseManualValue(ctrl.text);
    final status = item.avaliarStatus(valor);
    final theme = Theme.of(context);
    final subtitulo = _subtitleFor(item);
    final unidadeLabel = (item.unidade ?? '').isNotEmpty
        ? ' (${item.unidade})'
        : '';
    final helper = _statusHelper(status);
    final helperColor = _statusColor(status);

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: helperColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.titulo.isEmpty ? '(sem título)' : item.titulo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitulo, style: theme.textTheme.bodyMedium),
            ],
            if ((item.periodicidade ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Periodicidade: ${item.periodicidade}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if ((item.instrumento ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Instrumento: ${item.instrumento}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: InputDecoration(
                labelText: 'Medição$unidadeLabel',
                border: const OutlineInputBorder(),
                helperText: helper,
                helperStyle: TextStyle(color: helperColor),
              ),
              onChanged: (txt) {
                final v = _parseManualValue(txt);
                final novoStatus = item.avaliarStatus(v);
                widget.onSelect(novoStatus, txt);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomaticEntry(BuildContext context) {
    final item = widget.item;
    final styleLabel = Theme.of(context).textTheme.titleMedium;
    final styleSpec = Theme.of(context).textTheme.bodyMedium;

    final subtitulo = _subtitleFor(item);
    final tolerancias = item.tolerancias;

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.titulo.isEmpty ? '(sem título)' : item.titulo,
              style: styleLabel,
            ),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitulo, style: styleSpec),
            ],
            if ((item.periodicidade ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Periodicidade: ${item.periodicidade}', style: styleSpec),
            ],
            if ((item.instrumento ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Instrumento: ${item.instrumento}', style: styleSpec),
            ],
            const SizedBox(height: 10),
            if (_isVisualRugParalelismoOrAfins(item)) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    text: 'Aprovado',
                    bg: Colors.green.shade200,
                    border: Colors.green.shade600,
                    fg: Colors.green.shade900,
                    selected: item.medicao == 'Aprovado',
                    onTap: () => widget.onSelect(StatusMedida.ok, 'Aprovado'),
                  ),
                  _pill(
                    text: 'Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected: item.medicao == 'Reprovado',
                    onTap: () => widget.onSelect(
                      StatusMedida.reprovadaAcima,
                      'Reprovado',
                    ),
                  ),
                ],
              ),
            ] else if (_isTampao(item)) ...[
              Builder(
                builder: (context) {
                  final parts = _partsFromMedicao(item.medicao);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        text: 'Lado passa — Aprovado',
                        bg: Colors.green.shade200,
                        border: Colors.green.shade600,
                        fg: Colors.green.shade900,
                        selected: parts.contains('Lado passa — Aprovado'),
                        onTap: () {
                          final p = _partsFromMedicao(item.medicao);
                          p.removeWhere((e) => e.startsWith('Lado passa'));
                          p.add('Lado passa — Aprovado');
                          widget.onSelect(_statusFromParts(p), _joinParts(p));
                        },
                      ),
                      _pill(
                        text: 'Lado passa — Reprovado',
                        bg: Colors.red.shade100,
                        border: Colors.red.shade400,
                        selected: parts.contains('Lado passa — Reprovado'),
                        onTap: () {
                          final p = _partsFromMedicao(item.medicao);
                          p.removeWhere((e) => e.startsWith('Lado passa'));
                          p.add('Lado passa — Reprovado');
                          widget.onSelect(_statusFromParts(p), _joinParts(p));
                        },
                      ),
                      _pill(
                        text: 'Lado não passa — Aprovado',
                        bg: Colors.green.shade200,
                        border: Colors.green.shade600,
                        fg: Colors.green.shade900,
                        selected: parts.contains('Lado não passa — Aprovado'),
                        onTap: () {
                          final p = _partsFromMedicao(item.medicao);
                          p.removeWhere((e) => e.startsWith('Lado não passa'));
                          p.add('Lado não passa — Aprovado');
                          widget.onSelect(_statusFromParts(p), _joinParts(p));
                        },
                      ),
                      _pill(
                        text: 'Lado não passa — Reprovado',
                        bg: Colors.red.shade100,
                        border: Colors.red.shade400,
                        selected: parts.contains('Lado não passa — Reprovado'),
                        onTap: () {
                          final p = _partsFromMedicao(item.medicao);
                          p.removeWhere((e) => e.startsWith('Lado não passa'));
                          p.add('Lado não passa — Reprovado');
                          widget.onSelect(_statusFromParts(p), _joinParts(p));
                        },
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              Builder(
                builder: (context) {
                  final chips = <Widget>[];
                  for (var i = 0; i < tolerancias.length; i++) {
                    final raw = tolerancias[i];
                    final d = _toDoubleNum(raw);
                    StatusMedida st;
                    Color bg;
                    Color bd;
                    switch (i) {
                      case 0:
                        st = StatusMedida.reprovadaAbaixo;
                        bg = Colors.red.shade100;
                        bd = Colors.red.shade400;
                        break;
                      case 1:
                        st = StatusMedida.alertaAbaixo;
                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                        break;
                      case 2:
                        st = StatusMedida.alertaAcima;
                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                        break;
                      case 3:
                        st = StatusMedida.reprovadaAcima;
                        bg = Colors.red.shade100;
                        bd = Colors.red.shade400;
                        break;
                      default:
                        st = StatusMedida.alertaAbaixo;
                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                    }

                    final label = d != null
                        ? d.toStringAsFixed(2)
                        : raw.toString();
                    final selected = item.medicao == label;

                    chips.add(
                      _pill(
                        text: label,
                        bg: bg,
                        border: bd,
                        selected: selected,
                        onTap: () => widget.onSelect(st, label),
                      ),
                    );
                  }
                  final mid = chips.isEmpty ? 0 : (chips.length ~/ 2);
                  chips.insert(
                    mid,
                    _pill(
                      text: 'OK',
                      bg: Colors.green.shade200,
                      border: Colors.green.shade600,
                      fg: Colors.green.shade900,
                      selected: item.medicao == 'OK',
                      onTap: () => widget.onSelect(StatusMedida.ok, 'OK'),
                    ),
                  );

                  return Wrap(spacing: 8, runSpacing: 8, children: chips);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.manualEntry) {
      return _buildManualEntry(context);
    }
    return _buildAutomaticEntry(context);
  }
}
