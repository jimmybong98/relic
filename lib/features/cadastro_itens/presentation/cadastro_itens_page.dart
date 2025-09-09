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
  Map<String, TextEditingController> _controllersAdd = {};
  List<String> _camposAdd = [];

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
    setState(() {
      // o campo `idx_medida` será gerado automaticamente no backend,
      // portanto não deve aparecer para o usuário
      _camposAdd = [
        for (var c in campos)
          if (c != 'idx_medida') c,
      ];
      _controllersAdd = {for (var c in _camposAdd) c: TextEditingController()};
    });
  }

  Future<void> _adicionar() async {
    final dados = {for (var c in _camposAdd) c: _controllersAdd[c]!.text};
    final ok = await _service.inserir(_tabelaAdd, dados);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Registro adicionado' : 'Falha ao adicionar'),
      ),
    );
    if (ok) {
      // Mantém os campos de peça e operação preenchidos para facilitar
      // o cadastro de várias medidas na mesma peça/operacao
      for (var c in _camposAdd) {
        if (c != 'partnumber' && c != 'operacao') {
          _controllersAdd[c]!.clear();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Cadastro de novos itens'),
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
    return SingleChildScrollView(
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
                setState(() => _tabelaAdd = v);
                _loadCampos();
              }
            },
          ),
          ..._camposAdd.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextField(
                controller: _controllersAdd[c],
                decoration: InputDecoration(labelText: c),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _adicionar, child: const Text('Salvar')),
        ],
      ),
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
