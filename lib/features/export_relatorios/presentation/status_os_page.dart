import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../../../services/report_service.dart';

/// Page that lists all OS with their general status and sampling counts.
class StatusOsPage extends StatefulWidget {
  const StatusOsPage({super.key});

  @override
  State<StatusOsPage> createState() => _StatusOsPageState();
}

class _StatusOsPageState extends State<StatusOsPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];

  static const Map<String, String> _headerMap = {
    'os': 'OS',
    'status': 'Status',
    'reprovada_abaixo': 'Reprovada abaixo',
    'alerta_abaixo': 'Alerta abaixo',
    'ok': 'OK',
    'alerta_acima': 'Alerta acima',
    'reprovada_acima': 'Reprovada acima',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final data = await ReportService().fetchOsStatusOverview();
    if (!mounted) return;
    setState(() {
      _rows = data;
      _loading = false;
    });
  }

  String _formatarValor(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return '';
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headerMap.keys.toList();
    return Scaffold(
      appBar: const WindowBar(title: 'Status das OS', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: _loading ? null : _carregar,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Atualizar'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(child: Text('Nenhum dado'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: headers
                                  .map(
                                    (h) => DataColumn(
                                      label: Text(
                                        _headerMap[h] ?? h,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              rows: _rows
                                  .map(
                                    (row) => DataRow(
                                      cells: headers
                                          .map(
                                            (h) => DataCell(
                                              Text(
                                                _formatarValor(row, h),
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
