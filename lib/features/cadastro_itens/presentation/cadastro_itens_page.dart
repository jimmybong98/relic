import 'package:flutter/material.dart';
import 'package:admin/screens/main/components/side_menu.dart';

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
      _camposAdd = campos;
      _controllersAdd = {
        for (var c in campos) c: TextEditingController()
      };
    });
  }

  Future<void> _adicionar() async {
    final dados = {
      for (var c in _camposAdd) c: _controllersAdd[c]!.text
    };
    final ok = await _service.inserir(_tabelaAdd, dados);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Registro adicionado' : 'Falha ao adicionar'),
      ),
    );
  }

  Future<void> _buscarRegistros() async {
    final regs = await _service.fetchRegistros(
        _tabelaEdit, _partCtrl.text, _opCtrl.text);
    setState(() => _registros = regs);
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
      appBar: AppBar(title: const Text('Cadastro de novos itens')),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [Tab(text: 'Adicionar'), Tab(text: 'Editar')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAdicionar(),
                  _buildEditar(),
                ],
              ),
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
                  onPressed: _buscarRegistros, child: const Text('Buscar')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _registros.length,
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(_registros[index]);
              return ListTile(
                title: Text('Idx ${item['idx_medida']}: ${item['titulo'] ?? ''}'),
                onTap: () => _showEditDialog(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final controllers = {
      for (var e in item.entries)
        e.key: TextEditingController(text: '${e.value ?? ''}')
    };
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar idx ${item['idx_medida']}'),
        content: SingleChildScrollView(
          child: Column(
            children: controllers.keys
                .map(
                  (k) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: controllers[k],
                      decoration: InputDecoration(labelText: k),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final data = {
                for (var k in controllers.keys) k: controllers[k]!.text
              };
              Navigator.pop(context);
              _salvarEdicao(data);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
