import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../services/report_service.dart';

/// Page that displays report data directly without exporting to Excel.
class VisualizarRelatoriosPage extends StatefulWidget {
  const VisualizarRelatoriosPage({super.key});

  @override
  State<VisualizarRelatoriosPage> createState() =>
      _VisualizarRelatoriosPageState();
}

class _VisualizarRelatoriosPageState extends State<VisualizarRelatoriosPage> {
  final _osController = TextEditingController();
  String _tipo = 'FOR07';
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _osController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() => _loading = true);
    final section = _tipo == 'FOR07' ? 'full' : 'amostragem';
    final data = await ReportService().fetchOsReport(
      _osController.text,
      section: section,
    );
    final List<Map<String, dynamic>> rows = [];
    if (data != null) {
      if (_tipo == 'FOR07') {
        for (final e in (data['liberacao'] as List? ?? [])) {
          if (e is Map<String, dynamic>) {
            final raw = (e['created_at'] ?? '').toString();
            final createdAt =
                DateTime.tryParse(raw)?.toLocal().toString().split('.').first ??
                raw.replaceAll('T', ' ');
            rows.add({
              'created_at': createdAt,
              'etapa': 'Liberação',
              'partnumber': e['partnumber'],
              'maquina': e['maquina'],
              'faixa_texto': e['faixa_texto'],
              'titulo': e['titulo'],
              'medicao': e['medicao'],
              'status_medida': e['status_medida'] ?? e['statusMedida'] ?? '',
              'status_liberacao':
                  e['status_liberacao'] ??
                  e['statusLiberacao'] ??
                  e['status'] ??
                  '',
            });
          }
        }
        for (final e in (data['finalizacao'] as List? ?? [])) {
          if (e is Map<String, dynamic>) {
            final raw = (e['created_at'] ?? '').toString();
            final createdAt =
                DateTime.tryParse(raw)?.toLocal().toString().split('.').first ??
                raw.replaceAll('T', ' ');
            rows.add({
              'created_at': createdAt,
              'etapa': 'Encerramento',
              'partnumber': e['partnumber'],
              'maquina': e['maquina'],
              'faixa_texto': e['faixa_texto'],
              'titulo': e['titulo'],
              'medicao': e['medicao'],
              'status_medida': e['status_medida'] ?? e['statusMedida'] ?? '',
              'status_liberacao': e['status'] ?? '',
            });
          }
        }
      } else if (data[section] is List) {
        for (final e in (data[section] as List)) {
          if (e is Map<String, dynamic>) {
            final raw = (e['created_at'] ?? '').toString();
            final createdAt =
                DateTime.tryParse(raw)?.toLocal().toString().split('.').first ??
                raw.replaceAll('T', ' ');
            rows.add({
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
    if (!mounted) return;
    rows.sort(
      (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
    );
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerMap = _tipo == 'FOR07'
        ? const {
            'created_at': 'Horário',
            'etapa': 'Etapa',
            'partnumber': 'Partnumber',
            'maquina': 'Máquina',
            'faixa_texto': 'Faixa',
            'titulo': 'Título',
            'medicao': 'Medição',
            'status_medida': 'Status da medida',
            'status_liberacao': 'Status',
          }
        : const {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Visualizar relatórios')),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _osController,
              decoration: const InputDecoration(labelText: 'O.S'),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _tipo,
              items: const [
                DropdownMenuItem(value: 'FOR07', child: Text('FOR07')),
                DropdownMenuItem(value: 'FOR09', child: Text('FOR09')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _buscar,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buscar'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('Nenhum dado'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
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
                          rows: () {
                            final Map<String, List<Map<String, dynamic>>>
                            groups = {};
                            for (final r in _rows) {
                              final time = r['created_at'] ?? '';
                              final etapa = r['etapa'] ?? '';
                              final key = '$time|$etapa';
                              groups.putIfAbsent(key, () => []).add(r);
                            }
                            final sortedKeys = groups.keys.toList()..sort();
                            final List<DataRow> dataRows = [];
                            for (final key in sortedKeys) {
                              final parts = key.split('|');
                              final time = parts.first;
                              final etapa = parts.length > 1 ? parts[1] : '';
                              dataRows.add(
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        time,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        etapa,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    ...List.generate(
                                      headers.length - 2,
                                      (_) => DataCell(
                                        Text(
                                          '',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              for (final r in groups[key]!) {
                                dataRows.add(
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      ...headers
                                          .skip(1)
                                          .map(
                                            (h) => DataCell(
                                              Text(
                                                '${r[h] ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ],
                                  ),
                                );
                              }
                            }
                            return dataRows;
                          }(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
