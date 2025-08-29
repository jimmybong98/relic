import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../services/report_service.dart';

/// Page that allows the user to export reports to an Excel file.
class ExportRelatoriosPage extends StatefulWidget {
  const ExportRelatoriosPage({super.key});

  @override
  State<ExportRelatoriosPage> createState() => _ExportRelatoriosPageState();
}

class _ExportRelatoriosPageState extends State<ExportRelatoriosPage> {
  final _osController = TextEditingController();
  String _tipo = 'FOR07';
  bool _loading = false;

  @override
  void dispose() {
    _osController.dispose();
    super.dispose();
  }

  Future<void> _exportar() async {
    setState(() => _loading = true);
    final ok = await ReportService()
        .exportToExcel(os: _osController.text, tipo: _tipo);
    if (!mounted) return;
    setState(() => _loading = false);
    final msg = ok ? 'Relatório salvo com sucesso' : 'Falha ao exportar';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar relatórios')),
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
              onPressed: _loading ? null : _exportar,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Exportar'),
            ),
          ],
        ),
      ),
    );
  }
}
