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

        ({double? min, double? max})? anguloRange;
        for (final fonte in [faixaTexto, titulo]) {
          final texto = (fonte).toString();
          if (texto.trim().isEmpty) continue;
          final parsed = MedidaItem.parseAngleRangeFromText(texto);
          if (parsed != null) {
            anguloRange = parsed;
            break;
          }
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
          observacao: map['observacao']?.toString(),
          periodicidade: map['periodicidade']?.toString(),
          instrumento: map['instrumento']?.toString(),
          anguloMinimo: anguloRange?.min,
          anguloMaximo: anguloRange?.max,
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
