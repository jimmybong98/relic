import 'package:flutter/material.dart';

import '../../../controllers/machine_controller.dart';
import 'package:admin/widgets/window_bar.dart';
import 'package:admin/screens/main/components/side_menu.dart';

class CadastroMaquinasPage extends StatefulWidget {
  CadastroMaquinasPage({super.key, MachineController? controller})
    : controller = controller ?? MachineController();

  final MachineController controller;

  @override
  State<CadastroMaquinasPage> createState() => _CadastroMaquinasPageState();
}

class _CadastroMaquinasPageState extends State<CadastroMaquinasPage> {
  final _codigoCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _codigoCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      appBar: const WindowBar(title: 'Cadastro de máquinas', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
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
                          controller: _categoriaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _codigoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código da máquina',
                          ),
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
                                final categoria = _categoriaCtrl.text.trim();
                                if (codigo.isEmpty || categoria.isEmpty) return;
                                await ctrl.addMaquina(codigo, categoria);
                                if (ctrl.error == null) {
                                  _codigoCtrl.clear();
                                  _categoriaCtrl.clear();
                                }
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
                      return ListTile(
                        title: Text('${m.codigo} (${m.categoria})'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final catCtrl = TextEditingController(
                              text: m.categoria,
                            );
                            final codCtrl = TextEditingController(
                              text: m.codigo,
                            );
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Editar máquina'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: catCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Categoria',
                                        ),
                                      ),
                                      TextField(
                                        controller: codCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Código da máquina',
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Salvar'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (result == true) {
                              await ctrl.updateMaquina(
                                m.codigo,
                                codCtrl.text.trim(),
                                catCtrl.text.trim(),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
