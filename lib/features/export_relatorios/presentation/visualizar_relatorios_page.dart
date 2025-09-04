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
        final Map<String, Map<String, dynamic>> combined = {};
        for (final e in (data['liberacao'] as List? ?? [])) {
          if (e is Map<String, dynamic>) {
            final raw = (e['created_at'] ?? '').toString();
            final createdAt =
                DateTime.tryParse(raw)?.toLocal().toString().split('.').first ??
                raw.replaceAll('T', ' ');
            final key = '${e['partnumber']}_${e['idx_medida']}';
            combined[key] = {
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
                DateTime.tryParse(raw)?.toLocal().toString().split('.').first ??
                raw.replaceAll('T', ' ');
            final key = '${e['partnumber']}_${e['idx_medida']}';
            final row = combined.putIfAbsent(key, () {
              return {
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
            'created_at': 'Horário Inicial',
            'partnumber': 'Partnumber',
            'maquina': 'Máquina',
            'faixa_texto': 'Faixa',
            'medicao': 'Medição Inicial',
            'medicao_final': 'Medição Final',
            'created_at_final': 'Horário Final',

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
                          rows: _rows
                              .map(
                                (r) => DataRow(
                                  cells: headers
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
                                ),
                              )
                              .toList(),
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
