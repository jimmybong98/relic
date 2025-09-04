import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../services/report_service.dart';

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

  @override
  void dispose() {
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
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
            final Map<String, Map<String, dynamic>> combined = {};
            for (final e in (data['liberacao'] as List? ?? [])) {
              if (e is Map<String, dynamic>) {
                final raw = (e['created_at'] ?? '').toString();
                final createdAt =
                    DateTime.tryParse(
                      raw,
                    )?.toLocal().toString().split('.').first ??
                    raw.replaceAll('T', ' ');
                final key = '${e['partnumber']}_${e['idx_medida']}';
                combined[key] = {
                  'os': e['os'],
                  're_preparador': e['re_preparador'],
                  'created_at': createdAt,
                  'partnumber': e['partnumber'],
                  'maquina': e['maquina'],
                  'faixa_texto': e['faixa_texto'],
                  'medicao': e['medicao'],
                };
              }
            }
            for (final e in (data['finalizacao'] as List? ?? [])) {
              if (e is Map<String, dynamic>) {
                final raw = (e['created_at'] ?? '').toString();
                final createdAt =
                    DateTime.tryParse(
                      raw,
                    )?.toLocal().toString().split('.').first ??
                    raw.replaceAll('T', ' ');
                final key = '${e['partnumber']}_${e['idx_medida']}';
                final row = combined.putIfAbsent(key, () {
                  return {
                    'os': e['os'],
                    're_preparador': e['re_preparador'],
                    'created_at': '',
                    'partnumber': e['partnumber'],
                    'maquina': e['maquina'],
                    'faixa_texto': e['faixa_texto'],
                    'medicao': '',
                  };
                });
                row['created_at_final'] = createdAt;
                row['medicao_final'] = e['medicao'];
              }
            }
            rows.addAll(combined.values);
          } else {
            final list = data[section];
            if (list is List) {
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  final raw = (e['created_at'] ?? '').toString();
                  final createdAt =
                      DateTime.tryParse(
                        raw,
                      )?.toLocal().toString().split('.').first ??
                      raw.replaceAll('T', ' ');
                  rows.add({
                    'os': e['os'],
                    're_operador': e['re_operador'],
                    'created_at': createdAt,
                    'partnumber': e['partnumber'],
                    'maquina': e['maquina'],
                    'titulo': e['titulo'],
                    'instrumento': e['instrumento'],
                    'faixa_texto': e['faixa_texto'],
                    'escolha': e['escolha'],
                    'status': e['status'],
                  });
                }
              }
            }
          }
        }
        rows.sort(
          (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
        );
        return rows;
      } else {
        final part = _partCtrl.text.trim();
        final op = _opCtrl.text.trim();
        return await service.fetchReleases(
          tipo: _tipo,
          partnumber: part,
          operacao: op,
        );
      }
    }

    setState(() {
      _future = carregador();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                  DropdownMenuItem(value: 'operador', child: Text('Verificação do Processo')),
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
              final headerMap = _tipo == 'preparador'
                  ? const {
                      'os': 'OS',
                      're_preparador': 'RE',
                      'partnumber': 'Partnumber',
                      'maquina': 'Máquina',
                      'faixa_texto': 'Faixa',
                      'created_at': 'Horário Inicial',
                      'medicao': 'Medição Inicial',
                      'medicao_final': 'Medição Final',
                      'created_at_final': 'Horário Final',
                    }
                  : const {
                      'os': 'OS',
                      're_operador': 'RE',
                      'created_at': 'Horário',
                      'partnumber': 'Partnumber',
                      'maquina': 'Máquina',
                      'titulo': 'Título',
                      'instrumento': 'Instrumento',
                      'faixa_texto': 'Faixa',
                      'escolha': 'Escolha',
                      'status': 'Status',
                    };
              final headers = headerMap.keys.toList();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: headers
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            headerMap[h] ?? h,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  rows: dados
                      .map(
                        (r) => DataRow(
                          cells: headers
                              .map(
                                (h) => DataCell(
                                  Text(
                                    '${r[h] ?? ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
