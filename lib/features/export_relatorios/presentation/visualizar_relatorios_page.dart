import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../services/report_service.dart';

/// Page that displays report data directly without exporting to Excel.
class VisualizarRelatoriosPage extends StatefulWidget {
  const VisualizarRelatoriosPage({super.key});

  @override
  State<VisualizarRelatoriosPage> createState() => _VisualizarRelatoriosPageState();
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
    final section = _tipo == 'FOR07' ? 'liberacao' : 'amostragem';
    final data = await ReportService()
        .fetchOsReport(_osController.text, section: section);
    final List<Map<String, dynamic>> rows = [];
    if (data != null && data[section] is List) {
      for (final e in (data[section] as List)) {
        if (e is Map<String, dynamic>) {
          rows.add(e);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final headers = _rows.isNotEmpty ? _rows.first.keys.toList() : <String>[];
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
                      child: DataTable(
                        columns: headers
                            .map((h) => DataColumn(label: Text(h)))
                            .toList(),
                        rows: _rows
                            .map((r) => DataRow(
                                  cells: headers
                                      .map((h) =>
                                          DataCell(Text('${r[h] ?? ''}')))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

