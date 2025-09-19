import 'package:flutter/material.dart';

import 'package:admin/features/preparacao/data/models.dart';

class MeasurementTile extends StatelessWidget {
  final int index;
  final MedidaItem item;
  final void Function(StatusMedida status, String? medicao) onSelect;

  const MeasurementTile({
    super.key,
    required this.index,
    required this.item,
    required this.onSelect,
  });

  // ---------- helpers ----------
  String _norm(String? s) => (s ?? '').trim();
  String _nfd(String s) {
    // normalização simples (sem pacote intl)
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

  bool get _isVisualRugParalelismoOrAfins {
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

  bool get _isTampao {
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

  @override
  Widget build(BuildContext context) {
    final styleLabel = Theme.of(context).textTheme.titleMedium;
    final styleSpec = Theme.of(context).textTheme.bodyMedium;

    String subtitulo = item.faixaTexto;
    if (subtitulo.isEmpty && (item.minimo != null || item.maximo != null)) {
      final minStr = item.minimo?.toStringAsFixed(2) ?? '';
      final maxStr = item.maximo?.toStringAsFixed(2) ?? '';
      final uni = (item.unidade ?? '').isNotEmpty ? ' ${item.unidade}' : '';
      if (minStr.isNotEmpty && maxStr.isNotEmpty) {
        subtitulo = '$minStr – $maxStr$uni';
      } else if (minStr.isNotEmpty) {
        subtitulo = '≥ $minStr$uni';
      } else if (maxStr.isNotEmpty) {
        subtitulo = '≤ $maxStr$uni';
      }
    }

    // NÃO usar ?? [] se tolerancias for não-nulo (evita dead_null_aware_expression)
    final tolerancias = item.tolerancias;

    // ------- UI -------
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

            // Modo 1: Visual/Rug/Paralelismo/Anel de rosca passa/CQF/Simetria (binário)
            if (_isVisualRugParalelismoOrAfins) ...[
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
                    onTap: () => onSelect(StatusMedida.ok, 'Aprovado'),
                  ),
                  _pill(
                    text: 'Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected: item.medicao == 'Reprovado',
                    onTap: () =>
                        onSelect(StatusMedida.reprovadaAcima, 'Reprovado'),
                  ),
                ],
              ),
            ]
            // Modo 2: Tampão (4 botões)
            else if (_isTampao) ...[
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
                          onSelect(_statusFromParts(p), _joinParts(p));
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
                          onSelect(_statusFromParts(p), _joinParts(p));
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
                          onSelect(_statusFromParts(p), _joinParts(p));
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
                          onSelect(_statusFromParts(p), _joinParts(p));
                        },
                      ),
                    ],
                  );
                },
              ),
            ]
            // Modo 3: Pílulas de tolerância + OK
            else ...[
              Builder(
                builder: (context) {
                  final chips = <Widget>[];

                  // Monta as 4 pílulas coloridas na ordem recebida
                  for (var i = 0; i < tolerancias.length; i++) {
                    final raw = tolerancias[i];
                    final d = _toDoubleNum(raw);

                    // Define cores e status conforme a posição
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
                        onTap: () => onSelect(st, label),
                      ),
                    );
                  }

                  // Insere OK central
                  final mid = chips.isEmpty ? 0 : (chips.length ~/ 2);
                  chips.insert(
                    mid,
                    _pill(
                      text: 'OK',
                      bg: Colors.green.shade200,
                      border: Colors.green.shade600,
                      fg: Colors.green.shade900,
                      selected: item.medicao == 'OK',
                      onTap: () => onSelect(StatusMedida.ok, 'OK'),
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
}
