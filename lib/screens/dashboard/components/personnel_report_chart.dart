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

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) {
      try {
        dt = DateFormat(
          "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
          'en_US',
        ).parseUtc(raw);
      } catch (_) {}
    }
    return dt?.toLocal().toString().split('.').first ??
        raw.replaceAll('T', ' ');
  }

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
                final createdAt = _formatDate(e['created_at']);
                final key = '${e['partnumber']}_${e['idx_medida']}';
                combined[key] = {
                  'os': e['os'],
                  're_liberacao': e['re_preparador'],
                  're_finalizacao': '',
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
                final createdAt = _formatDate(e['created_at']);
                final key = '${e['partnumber']}_${e['idx_medida']}';
                final row = combined.putIfAbsent(key, () {
                  return {
                    'os': e['os'],
                    're_liberacao': '',
                    'created_at': '',
                    'partnumber': e['partnumber'],
                    'maquina': e['maquina'],
                    'faixa_texto': e['faixa_texto'],
                    'medicao': '',
                  };
                });
                row['created_at_final'] = createdAt;
                row['medicao_final'] = e['medicao'];
                row['re_finalizacao'] = e['re_preparador'];
              }
            }
            rows.addAll(combined.values);
          } else {
            final list = data[section];
            if (list is List) {
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  final createdAt = _formatDate(e['created_at']);
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
        final data = await service.fetchReleases(
          tipo: _tipo,
          partnumber: part,
          operacao: op,
        );
        final rows = <Map<String, dynamic>>[];
        for (final e in data) {
          if (e is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(e);
            map['created_at'] = _formatDate(e['created_at']);
            if (map.containsKey('created_at_final')) {
              map['created_at_final'] = _formatDate(e['created_at_final']);
            }
            rows.add(map);
          }
        }
        rows.sort(
          (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
        );
        return rows;
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
              final headerMap = _tipo == 'preparador'
                  ? const {
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
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 12,
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
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
