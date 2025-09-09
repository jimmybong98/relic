import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../../../services/report_service.dart';

/// Page that displays the time spent on an OS based on release and
/// finalization timestamps.
class TempoOsPage extends StatefulWidget {
  const TempoOsPage({super.key});

  @override
  State<TempoOsPage> createState() => _TempoOsPageState();
}

class _TempoOsPageState extends State<TempoOsPage> {
  final _osController = TextEditingController();
  bool _loading = false;
  List<Map<String, String>> _rows = [];

  @override
  void dispose() {
    _osController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _buscar() async {
    setState(() => _loading = true);
    final data = await ReportService().fetchOsReport(
      _osController.text,
      section: 'full',
    );
    final rows = <Map<String, String>>[];
    if (data != null) {
      final Map<String, Map<String, dynamic>> combined = {};
      for (final e in (data['liberacao'] as List? ?? [])) {
        if (e is Map<String, dynamic>) {
          final raw = (e['created_at'] ?? '').toString();
          final dt = DateTime.tryParse(raw)?.toLocal();
          final createdAt =
              dt?.toString().split('.').first ?? raw.replaceAll('T', ' ');
          final key = '${e['partnumber']}_${e['idx_medida']}';
          combined[key] = {
            'os': e['os'],
            're_liberacao': e['re_preparador'],
            're_finalizacao': '',
            'inicio': createdAt,
            'fim': '',
            'start': dt,
            'end': null,
          };
        }
      }
      for (final e in (data['finalizacao'] as List? ?? [])) {
        if (e is Map<String, dynamic>) {
          final raw = (e['created_at'] ?? '').toString();
          final dt = DateTime.tryParse(raw)?.toLocal();
          final createdAt =
              dt?.toString().split('.').first ?? raw.replaceAll('T', ' ');
          final key = '${e['partnumber']}_${e['idx_medida']}';
          final row = combined.putIfAbsent(key, () {
            return {
              'os': e['os'],
              're_liberacao': '',
              're_finalizacao': '',
              'inicio': '',
              'fim': createdAt,
              'start': null,
              'end': dt,
            };
          });
          row['fim'] = createdAt;
          row['re_finalizacao'] = e['re_preparador'];
          row['end'] = dt;
        }
      }
      for (final value in combined.values) {
        final start = value['start'] as DateTime?;
        final end = value['end'] as DateTime?;
        var tempo = '';
        if (start != null && end != null) {
          tempo = _formatDuration(end.difference(start));
        }
        rows.add({
          'os': value['os']?.toString() ?? '',
          're_liberacao': value['re_liberacao']?.toString() ?? '',
          're_finalizacao': value['re_finalizacao']?.toString() ?? '',
          'inicio': value['inicio']?.toString() ?? '',
          'fim': value['fim']?.toString() ?? '',
          'tempo': tempo,
        });
      }
    }
    if (!mounted) return;
    rows.sort((a, b) => (a['inicio'] ?? '').compareTo(b['inicio'] ?? ''));
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const headerMap = {
      'os': 'OS',
      're_liberacao': 'RE Liberação',
      're_finalizacao': 'RE Finalização',
      'inicio': 'Horário Liberação',
      'fim': 'Horário Finalização',
      'tempo': 'Tempo Gasto',
    };
    final headers = headerMap.keys.toList();
    return Scaffold(
      appBar: const WindowBar(title: 'Tempo por OS'),
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
                                            r[h] ?? '',
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
