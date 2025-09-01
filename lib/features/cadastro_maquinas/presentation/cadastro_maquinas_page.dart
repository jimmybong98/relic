import 'package:flutter/material.dart';

import '../../../controllers/machine_controller.dart';

class CadastroMaquinasPage extends StatefulWidget {
  const CadastroMaquinasPage({super.key, MachineController? controller})
      : controller = controller ?? MachineController();

  final MachineController controller;

  @override
  State<CadastroMaquinasPage> createState() => _CadastroMaquinasPageState();
}

class _CadastroMaquinasPageState extends State<CadastroMaquinasPage> {
  final _codigoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.fetchMaquinas();
  }

  void _onChanged() {
    if (!mounted) return;
    final err = widget.controller.error;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de máquinas')),
      body: ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codigoCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Código da máquina'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ctrl.isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(),
                            )
                          : FilledButton(
                              onPressed: () async {
                                final codigo = _codigoCtrl.text.trim();
                                if (codigo.isEmpty) return;
                                await ctrl.addMaquina(codigo);
                                if (ctrl.error == null) _codigoCtrl.clear();
                              },
                              child: const Text('Adicionar'),
                            ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: ctrl.maquinas.length,
                    itemBuilder: (context, index) {
                      final m = ctrl.maquinas[index];
                      return ListTile(title: Text(m));
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
