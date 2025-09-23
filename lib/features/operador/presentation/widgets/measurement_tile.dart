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
  TextEditingController? _chanfroAngCtrl;
  TextEditingController? _chanfroMedCtrl;
  String? _roscaSelection;

  @override
  void initState() {
    super.initState();
    _roscaSelection = widget.item.medicao;
    if (widget.manualEntry) {
      if (_isChanfro(widget.item)) {
        _ensureChanfroControllers();
        _syncChanfroControllers(widget.item.medicao);
      } else {
        _manualCtrl = TextEditingController(text: widget.item.medicao ?? '');
      }
    }
  }

  @override
  void didUpdateWidget(covariant MeasurementTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasChanfro = _isChanfro(oldWidget.item);
    final isChanfro = _isChanfro(widget.item);

    if (widget.manualEntry) {
      if (isChanfro) {
        _disposeManualController();
        _ensureChanfroControllers();
        if (!wasChanfro || oldWidget.item.medicao != widget.item.medicao) {
          _syncChanfroControllers(widget.item.medicao);
        }
      } else {
        _disposeChanfroControllers();
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
      }
    } else {
      _disposeManualController();
      _disposeChanfroControllers();
    }

    if (oldWidget.item.medicao != widget.item.medicao) {
      _roscaSelection = widget.item.medicao;
    }
  }

  @override
  void dispose() {
    _disposeManualController();
    _disposeChanfroControllers();
    super.dispose();
  }

  void _disposeManualController() {
    _manualCtrl?.dispose();
    _manualCtrl = null;
  }

  void _ensureChanfroControllers() {
    _chanfroAngCtrl ??= TextEditingController();
    _chanfroMedCtrl ??= TextEditingController();
  }

  void _disposeChanfroControllers() {
    _chanfroAngCtrl?.dispose();
    _chanfroAngCtrl = null;
    _chanfroMedCtrl?.dispose();
    _chanfroMedCtrl = null;
  }

  void _syncChanfroControllers(String? medicao) {
    _ensureChanfroControllers();
    final parts = (medicao ?? '').split('|');
    final ang = parts.isNotEmpty ? parts[0].trim() : '';
    final medida = parts.length > 1 ? parts[1].trim() : '';
    _setControllerText(_chanfroAngCtrl!, ang);
    _setControllerText(_chanfroMedCtrl!, medida);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
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
          'anel de rosca',
          'anel rosca',
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
          'anel de rosca',
          'anel rosca',
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

  bool _stringLooksLikeRoscaGauge(String? value) {
    final normalized = _nfd(_norm(value).toLowerCase());
    if (normalized.isEmpty || !normalized.contains('rosca')) return false;

    if (RegExp(r'\bmicro[\s-]*metros?\b').hasMatch(normalized)) return false;
    if (RegExp(r'\banel\s*de\s*rosca\b').hasMatch(normalized)) return true;

    return RegExp(
      r'\b(anel|cal|calib\w*|calibre\w*|galg\w*)\b',
    ).hasMatch(normalized);
  }

  bool _isRosca(MedidaItem item) {
    if (_stringLooksLikeRoscaGauge(item.instrumento)) return true;
    if (_norm(item.instrumento).isNotEmpty) return false;
    return _stringLooksLikeRoscaGauge(item.titulo);
  }

  bool _isChanfro(MedidaItem item) {
    final t = _norm(item.titulo);
    final faixa = _norm(item.faixaTexto);
    final inst = _norm(item.instrumento);
    final obs = _norm(item.observacao);
    return _containsAny(t, ['chanfro']) ||
        _containsAny(faixa, ['chanfro']) ||
        _containsAny(inst, ['chanfro']) ||
        _containsAny(obs, ['chanfro']);
  }

  bool _isRepetirTresPontos(MedidaItem item) {
    final t = _norm(item.titulo);
    final faixa = _norm(item.faixaTexto);
    return _containsAny(t, ['repetir 3 pontos de medicao']) ||
        _containsAny(faixa, ['repetir 3 pontos de medicao']);
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
    int? count,
  }) {
    final baseFg = fg ?? _fgOn(bg);
    final effectiveBg = selected ? border : bg;
    final effectiveBorder = selected ? border : border.withValues(alpha: 0.7);
    final effectiveFg = selected
        ? (fg != null ? Colors.white : _fgOn(effectiveBg))
        : baseFg;
    final displayCount = count;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: effectiveBorder, width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: border.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text),
              if (displayCount != null)
                TextSpan(
                  text: ' ($displayCount)',
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: effectiveFg.withOpacity(0.85),
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: effectiveFg,
          ),
        ),
      ),
    );
  }

  int _countFor(String label) {
    final counts = widget.item.contagens;
    final direct = counts[label];
    if (direct != null) return direct;
    final trimmed = label.trim();
    if (trimmed != label) {
      final trimmedCount = counts[trimmed];
      if (trimmedCount != null) return trimmedCount;
    }
    return 0;
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

  double? _parseAngleInput(String txt) {
    final sanitized = txt.replaceAll(RegExp("[°º'’′\"″”]"), '').trim();
    if (sanitized.isEmpty) return null;
    return _parseManualValue(sanitized);
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

  String _roscaHelper(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return 'Resultado aprovado';
      case StatusMedida.reprovadaAbaixo:
      case StatusMedida.reprovadaAcima:
        return 'Resultado reprovado';
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return 'Resultado fora da tolerância';
      case StatusMedida.pendente:
        return 'Selecione o resultado';
    }
  }

  String _repetirHelper(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return 'Resultado confirmado';
      case StatusMedida.reprovadaAbaixo:
      case StatusMedida.reprovadaAcima:
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return 'Resultado fora da tolerância';
      case StatusMedida.pendente:
        return 'Selecione OK para confirmar';
    }
  }

  String _chanfroHelper({
    required StatusMedida status,
    required bool hasAngle,
    required bool hasMedida,
    required bool medidaValida,
    required bool anguloValido,
    required StatusMedida medidaStatus,
    required StatusMedida anguloStatus,
  }) {
    if (!hasAngle || !hasMedida) {
      return 'Informe ângulo e medida para classificar';
    }
    if (!anguloValido) {
      return 'Ângulo inválido';
    }
    if (!medidaValida) {
      return 'Medida inválida';
    }
    if (anguloStatus != StatusMedida.ok &&
        anguloStatus != StatusMedida.pendente) {
      switch (anguloStatus) {
        case StatusMedida.reprovadaAbaixo:
          return 'Ângulo abaixo do mínimo';
        case StatusMedida.reprovadaAcima:
          return 'Ângulo acima do máximo';
        case StatusMedida.alertaAbaixo:
        case StatusMedida.alertaAcima:
          return 'Ângulo fora da tolerância';
        case StatusMedida.ok:
        case StatusMedida.pendente:
          break;
      }
    }
    if (medidaStatus != StatusMedida.ok &&
        medidaStatus != StatusMedida.pendente) {
      return _statusHelper(medidaStatus);
    }
    return _statusHelper(status);
  }

  Widget _buildManualEntry(BuildContext context) {
    final item = widget.item;
    final isChanfro = _isChanfro(item);
    final isRosca = !isChanfro && _isRosca(item);
    TextEditingController? ctrl;
    if (!isChanfro) {
      ctrl = _manualCtrl ??= TextEditingController(text: item.medicao ?? '');
    } else {
      _ensureChanfroControllers();
    }

    final roscaSelection = (_roscaSelection ?? item.medicao ?? '')
        .trim()
        .toLowerCase();
    final angleText = isChanfro ? _chanfroAngCtrl!.text.trim() : '';
    final medidaText = isChanfro
        ? _chanfroMedCtrl!.text.trim()
        : (ctrl != null ? ctrl.text : '');
    final isRepetir3 = !isChanfro && !isRosca && _isRepetirTresPontos(item);

    double? valor;
    if (isRosca || isRepetir3) {
      valor = null;
    } else if (isChanfro) {
      valor = _parseManualValue(medidaText);
    } else {
      valor = _parseManualValue(ctrl!.text);
    }

    double? angleValue;
    bool hasAngle = false;
    bool hasMedida = false;
    bool medidaValida = false;
    bool anguloValido = false;
    StatusMedida medidaStatus = StatusMedida.pendente;
    StatusMedida anguloStatus = StatusMedida.pendente;

    StatusMedida status;
    if (isRosca) {
      status = roscaSelection == 'aprovado'
          ? StatusMedida.ok
          : roscaSelection == 'reprovado'
          ? StatusMedida.reprovadaAcima
          : StatusMedida.pendente;
    } else if (isChanfro) {
      hasAngle = angleText.isNotEmpty;
      hasMedida = medidaText.trim().isNotEmpty;
      angleValue = _parseAngleInput(angleText);
      anguloValido = angleValue != null;
      medidaValida = valor != null;
      if (medidaValida) {
        medidaStatus = item.avaliarStatus(valor);
      }
      if (anguloValido) {
        anguloStatus = item.avaliarAngulo(angleValue);
      }
      if (!hasAngle || !hasMedida || !medidaValida || !anguloValido) {
        status = StatusMedida.pendente;
      } else if (medidaStatus != StatusMedida.ok) {
        status = medidaStatus;
      } else if (anguloStatus != StatusMedida.ok) {
        status = anguloStatus;
      } else {
        status = StatusMedida.ok;
      }
    } else if (isRepetir3) {
      status = item.status;
    } else {
      hasMedida = ctrl!.text.trim().isNotEmpty;
      medidaValida = valor != null;
      if (medidaValida) {
        medidaStatus = item.avaliarStatus(valor);
      }
      status = medidaValida ? medidaStatus : StatusMedida.pendente;
    }

    final theme = Theme.of(context);
    final subtitulo = _subtitleFor(item);
    final unidadeLabel = (item.unidade ?? '').isNotEmpty
        ? ' (${item.unidade})'
        : '';
    final helper = isRosca
        ? _roscaHelper(status)
        : isChanfro
        ? _chanfroHelper(
            status: status,
            hasAngle: hasAngle,
            hasMedida: hasMedida,
            medidaValida: medidaValida,
            anguloValido: anguloValido,
            medidaStatus: medidaStatus,
            anguloStatus: anguloStatus,
          )
        : isRepetir3
        ? _repetirHelper(status)
        : _statusHelper(status);
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
            if (isRosca) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    text: 'Aprovado',
                    bg: Colors.green.shade200,
                    border: Colors.green.shade600,
                    fg: Colors.green.shade900,
                    selected: roscaSelection == 'aprovado',
                    count: _countFor('Aprovado'),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _roscaSelection = 'Aprovado';
                      });
                      widget.onSelect(StatusMedida.ok, 'Aprovado');
                    },
                  ),
                  _pill(
                    text: 'Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected: roscaSelection == 'reprovado',
                    count: _countFor('Reprovado'),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _roscaSelection = 'Reprovado';
                      });
                      widget.onSelect(StatusMedida.reprovadaAcima, 'Reprovado');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(helper, style: TextStyle(color: helperColor)),
            ] else if (isChanfro) ...[
              TextField(
                controller: _chanfroAngCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Ângulo (°)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _handleChanfroChanged(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _chanfroMedCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: InputDecoration(
                  labelText: 'Medida$unidadeLabel',
                  border: const OutlineInputBorder(),
                  helperText: helper,
                  helperStyle: TextStyle(color: helperColor),
                ),
                onChanged: (_) => _handleChanfroChanged(),
              ),
            ] else if (isRepetir3) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    text: 'OK',
                    bg: Colors.green.shade200,
                    border: Colors.green.shade600,
                    fg: Colors.green.shade900,
                    selected:
                        item.status == StatusMedida.ok &&
                        (item.medicao ?? '').trim().toLowerCase() == 'ok',
                    count: _countFor('OK'),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      final alreadyOk =
                          item.status == StatusMedida.ok &&
                          (item.medicao ?? '').trim().toLowerCase() == 'ok';
                      widget.onSelect(
                        alreadyOk ? StatusMedida.pendente : StatusMedida.ok,
                        alreadyOk ? null : 'OK',
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(helper, style: TextStyle(color: helperColor)),
            ] else ...[
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
          ],
        ),
      ),
    );
  }

  void _handleChanfroChanged() {
    final angle = _chanfroAngCtrl?.text ?? '';
    final medida = _chanfroMedCtrl?.text ?? '';
    final angleNormalized = angle.trim();
    final medidaNormalized = medida.trim();
    final valor = _parseManualValue(medidaNormalized);
    final angleValue = _parseAngleInput(angleNormalized);
    final hasAngle = angleNormalized.isNotEmpty;
    final hasMedida = medidaNormalized.isNotEmpty;
    final medidaValida = valor != null;
    final anguloValido = angleValue != null;
    StatusMedida novoStatus;
    if (!hasAngle || !hasMedida || !medidaValida || !anguloValido) {
      novoStatus = StatusMedida.pendente;
    } else {
      final medidaStatus = widget.item.avaliarStatus(valor);
      if (medidaStatus != StatusMedida.ok) {
        novoStatus = medidaStatus;
      } else {
        final anguloStatus = widget.item.avaliarAngulo(angleValue);
        novoStatus = anguloStatus != StatusMedida.ok
            ? anguloStatus
            : StatusMedida.ok;
      }
    }
    final combined = (hasAngle || hasMedida)
        ? '${angleNormalized} | ${medidaNormalized}'
        : '';
    widget.onSelect(novoStatus, combined);
    setState(() {});
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
                    selected:
                        item.medicao == 'Aprovado' &&
                        item.status == StatusMedida.ok,
                    count: _countFor('Aprovado'),
                    onTap: () => widget.onSelect(StatusMedida.ok, 'Aprovado'),
                  ),
                  _pill(
                    text: 'Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected:
                        item.medicao == 'Reprovado' &&
                        item.status == StatusMedida.reprovadaAcima,
                    count: _countFor('Reprovado'),
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
                        count: _countFor('Lado passa — Aprovado'),
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
                        count: _countFor('Lado passa — Reprovado'),
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
                        count: _countFor('Lado não passa — Aprovado'),
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
                        count: _countFor('Lado não passa — Reprovado'),
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
                    final selected = item.medicao == label && item.status == st;

                    chips.add(
                      _pill(
                        text: label,
                        bg: bg,
                        border: bd,
                        selected: selected,
                        count: _countFor(label),
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
                      selected:
                          item.medicao == 'OK' &&
                          item.status == StatusMedida.ok,
                      count: _countFor('OK'),
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
