import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/controllers/machine_controller.dart';
import 'package:admin/screens/main/components/side_menu.dart';

class CadastroMaquinasPage extends ConsumerWidget {
  CadastroMaquinasPage({super.key});

  final _codeCtrl = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maquinas = ref.watch(machineListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Máquinas')),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código da máquina',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(machineListProvider.notifier)
                        .add(_codeCtrl.text);
                    _codeCtrl.clear();
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: maquinas.length,
                itemBuilder: (context, index) {
                  final code = maquinas[index];
                  return ListTile(title: Text(code));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
