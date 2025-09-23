// lib/features/preparacao/data/models.dart
import 'dart:convert';

import 'package:admin/utils/string_utils.dart';

enum StatusMedida {
  ok,
  alertaAcima,
  alertaAbaixo,
  reprovadaAcima,
  reprovadaAbaixo,
  pendente,
}

StatusMedida statusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'ok':
    case 'aprovado':
      return StatusMedida.ok;
    case 'alerta_acima':
    case 'alerta acima':
      return StatusMedida.alertaAcima;
    case 'alerta_abaixo':
    case 'alerta abaixo':
      return StatusMedida.alertaAbaixo;
    case 'alerta':
      // suporte a registros antigos sem direção
      return StatusMedida.alertaAcima;
    case 'reprovada_acima':
    case 'reprovada acima':
    case 'acima':
    case 'reprovada':
    case 'reprovado':
      return StatusMedida.reprovadaAcima;
    case 'reprovada_abaixo':
    case 'reprovada abaixo':
    case 'abaixo':
      return StatusMedida.reprovadaAbaixo;
    default:
      return StatusMedida.pendente;
  }
}

String statusToString(StatusMedida s) {
  switch (s) {
    case StatusMedida.ok:
      return 'OK';
    case StatusMedida.alertaAcima:
      return 'Alerta acima';
    case StatusMedida.alertaAbaixo:
      return 'Alerta abaixo';
    case StatusMedida.reprovadaAcima:
      return 'Reprovada acima';
    case StatusMedida.reprovadaAbaixo:
      return 'Reprovada abaixo';
    case StatusMedida.pendente:
      return 'pendente';
  }
}

class MedidaItem {
  // Básicos
  final String titulo;
  final int? indice;

  /// Texto amigável da faixa (ex.: "10,00 ~ 12,00 mm", "≥ 15,30 mm", "≤ 3,2 µm")
  final String faixaTexto;

  /// Limite mínimo aceito (opcional).
  final double? minimo;

  /// Limite máximo aceito (opcional).
  final double? maximo;

  /// Unidade de medida (ex.: "mm", "°", "µm", etc.).
  final String? unidade;

  // Metadados
  final StatusMedida status;

  /// Mantido como String? para compatibilidade com o restante do app.
  final String? medicao;
  final String? observacao;
  final String? periodicidade;
  final String? instrumento;

  /// Rótulos de tolerância (até 4) vindos do backend do Operador (AE/AF/AG/AH...).
  final List<String> tolerancias;
  final Map<String, int> contagens;
  final double? anguloMinimo;
  final double? anguloMaximo;

  MedidaItem({
    required this.titulo,
    this.indice,
    this.faixaTexto = '',
    this.minimo,
    this.maximo,
    this.unidade,
    this.status = StatusMedida.pendente,
    this.medicao,
    this.observacao,
    this.periodicidade,
    this.instrumento,
    this.tolerancias = const [],
    Map<String, int>? contagens,
    this.anguloMinimo,
    this.anguloMaximo,
  }) : contagens = Map.unmodifiable(contagens ?? const {});

  /// Avalia um valor numérico contra os limites.
  /// - Se só houver `minimo`, reprova **abaixo** do mínimo.
  /// - Se só houver `maximo`, reprova **acima** do máximo.
  /// - Se houver ambos, valida como faixa **inclusiva** [min..max].
  StatusMedida avaliarStatus(double? valor) {
    if (valor == null) return StatusMedida.pendente;

    if (minimo != null && valor < minimo!) {
      return StatusMedida.reprovadaAbaixo;
    }
    if (maximo != null && valor > maximo!) {
      return StatusMedida.reprovadaAcima;
    }
    return StatusMedida.ok;
  }

  StatusMedida avaliarAngulo(double? valor) {
    final possuiFaixa = anguloMinimo != null || anguloMaximo != null;
    if (!possuiFaixa) {
      return valor == null ? StatusMedida.pendente : StatusMedida.ok;
    }
    if (valor == null) return StatusMedida.pendente;
    if (anguloMinimo != null && valor < anguloMinimo!) {
      return StatusMedida.reprovadaAbaixo;
    }
    if (anguloMaximo != null && valor > anguloMaximo!) {
      return StatusMedida.reprovadaAcima;
    }
    return StatusMedida.ok;
  }

  // ---------- Helpers internos de parsing ----------
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }

  static String _normalizeLower(String s) {
    final rep = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    var t = s.toLowerCase().trim();
    rep.forEach((a, b) => t = t.replaceAll(a, b));
    return t;
  }

  static bool _isRugosidade(String t) {
    final tl = _normalizeLower(t);
    // qualquer “rug” + (“ra” ou “rz”)
    return tl.contains('rug') && (tl.contains('ra') || tl.contains('rz'));
  }

  static bool _hasMinToken(String t) {
    final tl = _normalizeLower(t);
    return tl.contains('minimo') || RegExp(r'\bmin\b').hasMatch(tl);
  }

  static bool _hasMaxToken(String t) {
    final tl = _normalizeLower(t);
    return tl.contains('maximo') || RegExp(r'\bmax\b').hasMatch(tl);
  }

  static double? _firstNumber(String s) {
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(s);
    return m == null ? null : _toDouble(m.group(0));
  }

  /// Extrai (min,max,unidade) a partir de um texto solto (faixa/valor único).
  /// Coberto:
  ///  - Faixa: "27,50-28,10", "27.50 ~ 28.10", "27,5 a 28,1", "10 a 12 mm"
  ///  - Único valor: retorna (v,v,uni)
  ///  - Com token “minimo” → (v,null,uni)
  ///  - Com token “maximo” → (null,v,uni)
  static ({double? min, double? max, String? uni}) _parseRangeAny(
    String texto,
  ) {
    if (texto.trim().isEmpty) return (min: null, max: null, uni: null);
    final s = texto.trim();

    // Faixa
    final m = RegExp(
      r'(-?\d+(?:[.,]\d+)?)\s*(?:-|–|~|a|ate|até|to)\s*(-?\d+(?:[.,]\d+)?)\s*([^\d\s]+.*)?$',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      var v1 = _toDouble(m.group(1));
      var v2 = _toDouble(m.group(2));
      final uni = (m.group(3) ?? '').trim().isEmpty
          ? null
          : (m.group(3) ?? '').trim();
      if (v1 != null && v2 != null && v1 > v2) {
        final tmp = v1;
        v1 = v2;
        v2 = tmp;
      }
      return (min: v1, max: v2, uni: uni);
    }

    // Único valor (com possíveis tokens de minimo/máximo)
    final v = _firstNumber(s);
    final uniMatch = RegExp(r'[a-zA-Zµ°]+[a-zA-Z0-9/%²³]*$').firstMatch(s);
    final uni = (uniMatch?.group(0) ?? '').trim().isEmpty
        ? null
        : uniMatch!.group(0)!.trim();

    if (v == null) return (min: null, max: null, uni: null);

    final hasMin = _hasMinToken(s);
    final hasMax = _hasMaxToken(s);
    if (hasMin && !hasMax) return (min: v, max: null, uni: uni);
    if (hasMax && !hasMin) return (min: null, max: v, uni: uni);

    // Sem tokens → valor exato
    return (min: v, max: v, uni: uni);
  }

  /// Gera um texto amigável para a faixa quando `faixaTexto` veio vazio.
  static String _makeFaixaTexto(double? min, double? max, String? uni) {
    final u = (uni ?? '').isNotEmpty ? ' $uni' : '';
    String fmt(double v) => v.toStringAsFixed(2);
    if (min != null && max != null) {
      if (min == 0 && max > 0) return '≤ ${fmt(max)}$u';
      return '${fmt(min)} – ${fmt(max)}$u';
    }
    if (min != null) return '≥ ${fmt(min)}$u';
    if (max != null) return '≤ ${fmt(max)}$u';
    return '';
  }

  static bool _isPlusMinusConnector(String raw, String compact) {
    if (raw.contains('±') || compact.contains('±')) return true;
    final lower = compact.toLowerCase();
    if (lower.contains('+/-') ||
        lower.contains('+/−') ||
        lower.contains('-/+')) {
      return true;
    }
    if (lower == '+-' || lower == '-+' || lower == '+−' || lower == '−+') {
      return true;
    }
    return false;
  }

  static bool _isRangeConnector(String raw, String normalized, String compact) {
    if (_isPlusMinusConnector(raw, compact)) return false;
    if (raw.contains('-') ||
        raw.contains('–') ||
        raw.contains('—') ||
        raw.contains('~')) {
      return true;
    }
    switch (compact) {
      case 'a':
      case 'ate':
      case 'to':
        return true;
    }
    return false;
  }

  static double? _parseAngleToken(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(',', '.');
    final matches = RegExp(r'-?\d+(?:\.\d+)?').allMatches(s).toList();
    if (matches.isEmpty) return null;
    final numbers = matches
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    if (numbers.isEmpty) return null;
    double value = numbers[0];
    if (numbers.length >= 2) {
      value += numbers[1] / 60.0;
    }
    if (numbers.length >= 3) {
      value += numbers[2] / 3600.0;
    }
    return value;
  }

  static ({double? min, double? max})? parseAngleRangeFromText(String texto) {
    if (texto.trim().isEmpty) return null;
    final normalized = texto.replaceAll(',', '.');
    final pattern = RegExp(
      "-?\\d+(?:[.,]\\d+)?\\s*[°º](?:\\s*\\d+[\\u2019\\u2032']?)?(?:\\s*\\d+(?:[\\u0022\\u2033\\u201d]))?",
    );
    final matches = pattern.allMatches(normalized).toList();
    if (matches.length < 2) return null;

    for (var i = 0; i < matches.length - 1; i++) {
      final rawA = normalized.substring(matches[i].start, matches[i].end);
      final rawB = normalized.substring(
        matches[i + 1].start,
        matches[i + 1].end,
      );
      final betweenRaw = normalized.substring(
        matches[i].end,
        matches[i + 1].start,
      );
      if (betweenRaw.trim().isEmpty) continue;

      final connectorNormalized = _normalizeLower(betweenRaw);
      final connectorCompact = connectorNormalized.replaceAll(
        RegExp(r'\s+'),
        '',
      );
      final valueA = _parseAngleToken(rawA);
      final valueB = _parseAngleToken(rawB);
      if (valueA == null || valueB == null) continue;

      if (_isPlusMinusConnector(betweenRaw, connectorCompact)) {
        final range = [valueA - valueB, valueA + valueB]..sort();
        return (min: range.first, max: range.last);
      }

      if (_isRangeConnector(
        betweenRaw,
        connectorNormalized,
        connectorCompact,
      )) {
        final range = [valueA, valueB]..sort();
        return (min: range.first, max: range.last);
      }
    }

    return null;
  }

  factory MedidaItem.fromMap(Map<String, dynamic> map) {
    // Valores diretos do JSON
    String titulo = (map['titulo'] ?? '').toString();
    String faixa = (map['faixaTexto'] ?? map['faixa_texto'] ?? '').toString();

    double? minimo = _toDouble(map['minimo'] ?? map['min']);
    double? maximo = _toDouble(map['maximo'] ?? map['max']);
    String? uni = (map['unidade']?.toString().trim().isEmpty ?? true)
        ? null
        : map['unidade']!.toString().trim();

    // Se não veio min/max, tenta extrair da faixa; se ainda não, tenta do título.
    if (minimo == null && maximo == null) {
      final r1 = _parseRangeAny(faixa);
      minimo = r1.min;
      maximo = r1.max;
      uni ??= r1.uni;
      if (minimo == null && maximo == null) {
        final r2 = _parseRangeAny(titulo);
        minimo = r2.min;
        maximo = r2.max;
        uni ??= r2.uni;
      }
    }

    // Regra especial de Rugosidade: valor único vira 0..valor (OK se <= valor)
    if (_isRugosidade(titulo)) {
      final limite = maximo ?? minimo;
      if (limite != null) {
        minimo = 0.0;
        maximo = limite;
      }
    }

    // Correção para ângulos: alguns registros vêm com min/max negativos ou
    // invertidos (ex.: -17, 13 representando 13°–17°). Normaliza para
    // valores absolutos e ordenados quando o item é um ângulo.
    final tituloNorm = _normalizeLower(titulo);
    final isAngulo =
        (uni != null && RegExp(r'[°º]').hasMatch(uni)) ||
        tituloNorm.contains('angulo');
    if (isAngulo && minimo != null && maximo != null) {
      final vals = [minimo.abs(), maximo.abs()]..sort();
      minimo = vals.first;
      maximo = vals.last;
    }

    // Se faixaTexto veio vazio, monta automaticamente a partir de min/max/unidade
    final faixaOut = (faixa.isNotEmpty)
        ? faixa
        : _makeFaixaTexto(minimo, maximo, uni);

    // Tolerâncias para Operador (lista de rótulos), se existirem
    final tol = (map['tolerancias'] is List)
        ? (map['tolerancias'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    final rawObservacao = map['observacao'];
    final rawPeriodicidade = map['periodicidade'];
    final rawInstrumento = map['instrumento'];
    final observacao = rawObservacao?.toString();
    final periodicidade = rawPeriodicidade?.toString();
    final instrumento = rawInstrumento?.toString();

    ({double? min, double? max})? anguloRange;
    for (final fonte in [faixa, titulo, observacao, instrumento]) {
      final texto = (fonte ?? '').toString();
      if (texto.trim().isEmpty) continue;
      final parsed = parseAngleRangeFromText(texto);
      if (parsed != null) {
        anguloRange = parsed;
        break;
      }
    }

    final rawCounts = map['contagens'];
    final counts = <String, int>{};
    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        if (key == null) return;
        final label = key.toString();
        if (label.isEmpty) return;
        int? parsed;
        final v = value;
        if (v is num) {
          parsed = v.toInt();
        } else {
          parsed = int.tryParse(v.toString());
        }
        if (parsed != null && parsed >= 0) {
          counts[label] = parsed;
        }
      });
    }

    int? idx;
    final rawIdx =
        map['indice'] ?? map['idx_medida'] ?? map['idx'] ?? map['index'];
    if (rawIdx is num) {
      idx = rawIdx.toInt();
    } else if (rawIdx != null) {
      idx = int.tryParse(rawIdx.toString());
    }

    return MedidaItem(
      titulo: titulo,
      indice: idx,
      faixaTexto: faixaOut,
      minimo: minimo,
      maximo: maximo,
      unidade: uni,
      status: statusFromString(map['status']?.toString()),
      medicao: map['medicao']?.toString(),
      observacao: observacao,
      periodicidade: periodicidade,
      instrumento: instrumento,
      tolerancias: tol,
      contagens: counts,
      anguloMinimo: anguloRange?.min,
      anguloMaximo: anguloRange?.max,
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'indice': indice,
    'faixaTexto': faixaTexto,
    'minimo': minimo,
    'maximo': maximo,
    'unidade': unidade,
    'status': statusToString(status),
    'medicao': medicao,
    'observacao': observacao,
    'periodicidade': periodicidade,
    'instrumento': instrumento,
    'tolerancias': tolerancias,
    'contagens': contagens,
  };
}

class PreparacaoResultado {
  final String re;
  final String partnumber;
  final String operacao;
  final String maquina;
  final List<MedidaItem> medidas;

  PreparacaoResultado({
    required this.re,
    required this.partnumber,
    required this.operacao,
    required this.maquina,
    required this.medidas,
  });

  Map<String, dynamic> toMap() => {
    're': re,
    'partnumber': normalizeCode(partnumber),
    'operacao': normalizeCode(operacao),
    'maquina': maquina,
    'medidas': medidas.map((e) => e.toMap()).toList(),
  };

  String toJson() => jsonEncode(toMap());
}
