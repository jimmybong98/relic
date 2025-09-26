import 'package:flutter/material.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';

import '../../../services/supervisao_service.dart';

class CadastroItensPage extends StatefulWidget {
  const CadastroItensPage({super.key});

  @override
  State<CadastroItensPage> createState() => _CadastroItensPageState();
}

class _CadastroItensPageState extends State<CadastroItensPage>
    with SingleTickerProviderStateMixin {
  final _service = SupervisaoService();

  String _tabelaAdd = 'FOR07';
  final _partAddCtrl = TextEditingController();
  final _opAddCtrl = TextEditingController();
  List<String> _camposAdd = [];
  List<Map<String, TextEditingController>> _addControllers = [];
  bool _showAddCards = false;

  /// Controladores dos campos de edição para cada registro buscado
  List<Map<String, TextEditingController>> _editControllers = [];

  String _tabelaEdit = 'FOR07';
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();
  List<Map<String, dynamic>> _registros = [];

  @override
  void initState() {
    super.initState();
    _loadCampos();
  }

  Future<void> _loadCampos() async {
    final campos = await _service.fetchCampos(_tabelaAdd);
    if (!mounted) return;
    setState(() {
      // o campo `idx_medida` será gerado automaticamente no backend,
      // portanto não deve aparecer para o usuário. Os campos de
      // identificação da peça ficam fora dos cards de medidas.
      _camposAdd = [
        for (var c in campos)
          if (c != 'idx_medida' && c != 'partnumber' && c != 'operacao') c,
      ];
    });
  }

  Map<String, TextEditingController> _createAddControllers() {
    return {
      for (var c in _camposAdd) c: TextEditingController(),
    };
  }

  void _resetAddControllers() {
    for (final entry in _addControllers) {
      for (final ctrl in entry.values) {
        ctrl.dispose();
      }
    }
    _addControllers = [];
  }

  void _addNovaMedida() {
    setState(() {
      _addControllers = [..._addControllers, _createAddControllers()];
    });
  }

  void _removerMedida(int index) {
    setState(() {
      final removed = _addControllers.removeAt(index);
      for (final ctrl in removed.values) {
        ctrl.dispose();
      }
    });
  }

  Future<void> _prepararCadastro() async {
    await _loadCampos();
    if (!mounted) return;
    setState(() {
      _resetAddControllers();
      _addControllers.add(_createAddControllers());
      _showAddCards = true;
    });
  }

  Future<void> _adicionar() async {
    final part = _partAddCtrl.text.trim();
    final op = _opAddCtrl.text.trim();
    if (part.isEmpty || op.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o partnumber e a operação.')),
      );
      return;
    }

    if (_addControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma medida.')),
      );
      return;
    }

    var houveAlgumEnvio = false;
    var sucessoTotal = true;

    for (final mapa in _addControllers) {
      final dados = <String, dynamic>{
        'partnumber': part,
        'operacao': op,
      };
      var possuiDados = false;
      for (final campo in _camposAdd) {
        final valor = mapa[campo]!.text;
        dados[campo] = valor;
        if (valor.isNotEmpty) possuiDados = true;
      }

      if (!possuiDados) {
        continue;
      }

      houveAlgumEnvio = true;
      final ok = await _service.inserir(_tabelaAdd, dados);
      if (!ok) sucessoTotal = false;
    }

    if (!mounted) return;

    if (!houveAlgumEnvio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos de ao menos uma medida.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sucessoTotal
              ? 'Medidas cadastradas com sucesso.'
              : 'Falha ao cadastrar algumas medidas.',
        ),
      ),
    );

    if (sucessoTotal) {
      for (final mapa in _addControllers) {
        for (final ctrl in mapa.values) {
          ctrl.clear();
        }
      }
    }
  }

  Future<void> _buscarRegistros() async {
    final regs = await _service.fetchRegistros(
      _tabelaEdit,
      _partCtrl.text,
      _opCtrl.text,
    );
    final lista = regs
        .map((e) => Map<String, dynamic>.from(e)..remove('id'))
        .toList();
    setState(() {
      _registros = lista;
      _editControllers = lista
          .map(
            (item) => {
          for (var entry in item.entries)
            entry.key: TextEditingController(text: '${entry.value ?? ''}'),
        },
      )
          .toList();
    });
  }

  Future<void> _salvarEdicao(Map<String, dynamic> item) async {
    final ok = await _service.atualizar(_tabelaEdit, item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Registro atualizado' : 'Falha ao atualizar'),
      ),
    );
  }

  @override
  void dispose() {
    _partAddCtrl.dispose();
    _opAddCtrl.dispose();
    _resetAddControllers();
    _partCtrl.dispose();
    _opCtrl.dispose();
    for (final ctrlMap in _editControllers) {
      for (final ctrl in ctrlMap.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Cadastro de novos itens', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Adicionar'),
                Tab(text: 'Editar'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [_buildAdicionar(), _buildEditar()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdicionar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButton<String>(
                value: _tabelaAdd,
                items: const [
                  DropdownMenuItem(value: 'FOR07', child: Text('FOR07')),
                  DropdownMenuItem(value: 'FOR09', child: Text('FOR09')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _tabelaAdd = v;
                      _showAddCards = false;
                      _resetAddControllers();
                    });
                    _loadCampos();
                  }
                },
              ),
              TextField(
                controller: _partAddCtrl,
                decoration: const InputDecoration(labelText: 'Código da peça'),
              ),
              TextField(
                controller: _opAddCtrl,
                decoration: const InputDecoration(labelText: 'Operação'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _prepararCadastro,
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        if (_showAddCards)
          Expanded(
            child: ListView.builder(
              itemCount: _addControllers.length,
              itemBuilder: (context, index) {
                final ctrlMap = _addControllers[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Medida ${index + 1}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (_addControllers.length > 1)
                              IconButton(
                                onPressed: () => _removerMedida(index),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remover medida',
                              ),
                          ],
                        ),
                        ..._camposAdd.map(
                              (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: TextField(
                              controller: ctrlMap[c],
                              decoration: InputDecoration(labelText: c),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_showAddCards)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addNovaMedida,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar medida'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _adicionar,
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButton<String>(
                value: _tabelaEdit,
                items: const [
                  DropdownMenuItem(value: 'FOR07', child: Text('FOR07')),
                  DropdownMenuItem(value: 'FOR09', child: Text('FOR09')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _tabelaEdit = v);
                },
              ),
              TextField(
                controller: _partCtrl,
                decoration: const InputDecoration(labelText: 'Código da peça'),
              ),
              TextField(
                controller: _opCtrl,
                decoration: const InputDecoration(labelText: 'Operação'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _buscarRegistros,
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _registros.length,
            itemBuilder: (context, index) {
              final item = _registros[index];
              final ctrls = _editControllers[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ...item.keys.map(
                            (k) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: ctrls[k],
                            decoration: InputDecoration(labelText: k),
                            enabled: ![
                              'idx_medida',
                              'partnumber',
                              'operacao',
                            ].contains(k),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () {
                            final data = {
                              for (var k in ctrls.keys) k: ctrls[k]!.text,
                            };
                            _salvarEdicao(data);
                          },
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}