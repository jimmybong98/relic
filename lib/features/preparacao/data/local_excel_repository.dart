// lib/features/preparacao/data/local_excel_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'medidas_repository.dart';
import 'models.dart';

/// Repositório local que pode ler:
/// - JSON embarcado via [assetPath]; OU
/// - (placeholder) uma planilha indicada por [planilhaPath] e aba [aba].
///
/// OBS: A leitura de planilha é deixada como TODO (depende do package que você usa
/// para XLS/XLSX/CSV). Por ora, retorna lista vazia para esse modo (mas compila).
class LocalExcelRepository implements MedidasRepository {
  /// Caminho do asset JSON (ex.: 'assets/medidas.json').
  final String? assetPath;

  /// Caminho da planilha local (ex.: '/storage/emulated/0/Download/medidas.xlsx').
  final String? planilhaPath;

  /// Nome da aba da planilha (ex.: 'CADASTRO').
  final String? aba;

  /// Você pode instanciar de duas formas:
  /// - LocalExcelRepository(assetPath: 'assets/medidas.json')
  /// - LocalExcelRepository(planilhaPath: '/caminho/arquivo.xlsx', aba: 'CADASTRO')
  LocalExcelRepository({this.assetPath, this.planilhaPath, this.aba})
    : assert(
        assetPath != null || planilhaPath != null,
        'Informe assetPath OU planilhaPath',
      );

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
    String? os,
  }) async {
    // Prioriza JSON embarcado se informado.
    if (assetPath != null) {
      final raw = await rootBundle.loadString(assetPath!);
      final data = jsonDecode(raw);

      if (data is! List) return <MedidaItem>[];

      return data.map<MedidaItem>((e) {
        final map = (e as Map).cast<String, dynamic>();

        final titulo = (map['titulo'] ?? '').toString();
        String faixaTexto = (map['faixaTexto'] ?? '').toString();
        double? min = _toDouble(map['minimo'] ?? map['min']);
        double? max = _toDouble(map['maximo'] ?? map['max']);
        String? unidade = map['unidade']?.toString();
        int? indice;
        final rawIdx =
            map['indice'] ?? map['idx_medida'] ?? map['idx'] ?? map['index'];
        if (rawIdx is num) {
          indice = rawIdx.toInt();
        } else if (rawIdx != null) {
          indice = int.tryParse(rawIdx.toString());
        }

        if (faixaTexto.isEmpty && (min != null || max != null)) {
          final minStr = min?.toStringAsFixed(2) ?? '';
          final maxStr = max?.toStringAsFixed(2) ?? '';
          final uni = (unidade ?? '').isNotEmpty ? ' $unidade' : '';
          if (min != null && max != null) {
            faixaTexto = '$minStr ~ $maxStr$uni';
          } else if (min != null) {
            faixaTexto = '≥ $minStr$uni';
          } else if (max != null) {
            faixaTexto = '≤ $maxStr$uni';
          }
        }

        final observacao = map['observacao']?.toString();
        final periodicidade = map['periodicidade']?.toString();
        final instrumento = map['instrumento']?.toString();

        final rawTolerancias = map['tolerancias'];
        final tolerancias = (rawTolerancias is List)
            ? rawTolerancias.map((e) => e.toString()).toList()
            : const <String>[];

        final rawContagens = map['contagens'];
        final contagens = <String, int>{};
        if (rawContagens is Map) {
          rawContagens.forEach((key, value) {
            if (key == null) return;
            final label = key.toString();
            if (label.isEmpty) return;
            int? parsed;
            if (value is num) {
              parsed = value.toInt();
            } else {
              parsed = int.tryParse(value.toString());
            }
            if (parsed != null && parsed >= 0) {
              contagens[label] = parsed;
            }
          });
        }

        double? anguloMinDeduced;
        double? anguloMaxDeduced;

        void mergeAngleRange(({double? min, double? max})? candidate) {
          if (candidate == null) return;
          final candMin = candidate.min;
          final candMax = candidate.max;
          if (candMin != null) {
            if (anguloMinDeduced == null || candMin < anguloMinDeduced!) {
              anguloMinDeduced = candMin;
            }
          }
          if (candMax != null) {
            if (anguloMaxDeduced == null || candMax > anguloMaxDeduced!) {
              anguloMaxDeduced = candMax;
            }
          }
        }

        double? parseAngleTokenLocal(String rawText) {
          var s = rawText.trim();
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
          if (numbers.length >= 2) value += numbers[1] / 60.0;
          if (numbers.length >= 3) value += numbers[2] / 3600.0;
          return value;
        }

        double? parseAngleValue(dynamic rawValue) {
          if (rawValue == null) return null;
          if (rawValue is num) return rawValue.toDouble();
          final text = rawValue.toString().trim();
          if (text.isEmpty) return null;
          final token = parseAngleTokenLocal(text);
          if (token != null) return token;
          final sanitized = text
              .replaceAll(RegExp(r'[°º]'), '')
              .replaceAll(',', '.');
          return double.tryParse(sanitized);
        }

        ({double? min, double? max})? parseAnglePayload(dynamic rawValue) {
          if (rawValue == null) return null;
          if (rawValue is num) {
            final v = rawValue.toDouble();
            return (min: v, max: v);
          }
          final text = rawValue.toString().trim();
          if (text.isEmpty) return null;
          final parsed = MedidaItem.parseAngleRangeFromText(text);
          if (parsed != null) return parsed;
          final single = parseAngleValue(text);
          if (single != null) return (min: single, max: single);
          return null;
        }

        bool textMentionsAngle(String text) {
          var normalized = text.toLowerCase();
          const repl = {
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
          repl.forEach(
            (from, to) => normalized = normalized.replaceAll(from, to),
          );
          return text.contains('°') ||
              text.contains('º') ||
              normalized.contains('grau') ||
              normalized.contains('angulo');
        }

        map.forEach((key, value) {
          final normalizedKey = key.toString().toLowerCase();
          if (!normalizedKey.contains('angulo')) return;
          if (normalizedKey.contains('min')) {
            final parsed = parseAngleValue(value);
            if (parsed != null &&
                (anguloMinDeduced == null || parsed < anguloMinDeduced!)) {
              anguloMinDeduced = parsed;
            }
            return;
          }
          if (normalizedKey.contains('max')) {
            final parsed = parseAngleValue(value);
            if (parsed != null &&
                (anguloMaxDeduced == null || parsed > anguloMaxDeduced!)) {
              anguloMaxDeduced = parsed;
            }
            return;
          }
          mergeAngleRange(parseAnglePayload(value));
        });

        for (final fonte in [faixaTexto, titulo, observacao, instrumento]) {
          final texto = (fonte ?? '').toString().trim();
          if (texto.isEmpty) continue;
          if (!textMentionsAngle(texto)) continue;
          mergeAngleRange(parseAnglePayload(texto));
        }

        for (final label in tolerancias) {
          final texto = label.trim();
          if (texto.isEmpty) continue;
          if (!textMentionsAngle(texto)) continue;
          mergeAngleRange(parseAnglePayload(texto));
        }

        if (anguloMinDeduced != null &&
            anguloMaxDeduced != null &&
            anguloMinDeduced! > anguloMaxDeduced!) {
          final tmp = anguloMinDeduced;
          anguloMinDeduced = anguloMaxDeduced;
          anguloMaxDeduced = tmp;
        }

        return MedidaItem(
          titulo: titulo,
          indice: indice,
          faixaTexto: faixaTexto,
          minimo: min,
          maximo: max,
          unidade: unidade,
          status: statusFromString(map['status']?.toString()),
          medicao: map['medicao']?.toString(),
          observacao: observacao,
          periodicidade: periodicidade,
          instrumento: instrumento,
          tolerancias: tolerancias,
          contagens: contagens,
          anguloMinimo: anguloMinDeduced,
          anguloMaximo: anguloMaxDeduced,
        );
      }).toList();
    }

    // TODO: Implementar leitura real de planilha (XLS/XLSX/CSV) usando o pacote escolhido.
    // Ex.: 'excel', 'syncfusion_flutter_xlsio', 'csv', etc.
    if (kDebugMode) {
      // Só pra dar um toque no console durante dev.
      print(
        'LocalExcelRepository: leitura de planilha não implementada ainda. caminho=$planilhaPath aba=$aba',
      );
    }
    return <MedidaItem>[];
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    // Local: não envia; apenas simula sucesso.
    await Future<void>.value();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }
}
