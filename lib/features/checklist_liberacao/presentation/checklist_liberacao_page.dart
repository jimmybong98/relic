import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../services/checklist_liberacao_service.dart';
import '../../../services/machine_service.dart';
import '../../../widgets/window_bar.dart';

enum ChecklistAnswer { sim, nao, naoAplica }

extension ChecklistAnswerLabel on ChecklistAnswer {
  String get label {
    switch (this) {
      case ChecklistAnswer.sim:
        return 'Sim';
      case ChecklistAnswer.nao:
        return 'Não';
      case ChecklistAnswer.naoAplica:
        return 'N/A';
    }
  }

  String get apiValue {
    switch (this) {
      case ChecklistAnswer.sim:
        return 'sim';
      case ChecklistAnswer.nao:
        return 'nao';
      case ChecklistAnswer.naoAplica:
        return 'nao_aplica';
    }
  }
}

class ChecklistQuestion {
  const ChecklistQuestion({required this.id, required this.text});

  final String id;
  final String text;
}

class ChecklistGroup {
  const ChecklistGroup({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<ChecklistQuestion> questions;
}

const List<ChecklistGroup> _checklistGroups = [
  ChecklistGroup(
    id: 'setor_organizacao',
    title: 'Setor e organização',
    questions: [
      ChecklistQuestion(
        id: 'setor_organizacao_limpeza',
        text: 'O setor está organizado e limpo? 5S',
      ),
      ChecklistQuestion(
        id: 'setor_organizacao_iluminacao',
        text: 'A iluminação está adequada?',
      ),
      ChecklistQuestion(
        id: 'setor_organizacao_identificacao',
        text: 'Entrada e saída de processo está identificada?',
      ),
      ChecklistQuestion(
        id: 'setor_organizacao_segregacao',
        text: 'Pessoal para segregar produção não conforme?',
      ),
      ChecklistQuestion(
        id: 'setor_organizacao_materiais',
        text: 'Possui material necessário para rotina operacional?',
      ),
    ],
  ),
  ChecklistGroup(
    id: 'produto_documentos',
    title: 'Produto e Documentos',
    questions: [
      ChecklistQuestion(
        id: 'produto_documentos_disponivel',
        text: 'A documentação está disponível? (FOR08, FOR09, FOR13, FOR31)',
      ),
      ChecklistQuestion(
        id: 'produto_documentos_placa',
        text: 'A placa de liberação está no recipiente?',
      ),
      ChecklistQuestion(
        id: 'produto_documentos_dados',
        text: 'Possui todos os dados na ordem?',
      ),
      ChecklistQuestion(
        id: 'produto_documentos_estado',
        text: 'Os documentos estão em bom estado?',
      ),
    ],
  ),
  ChecklistGroup(
    id: 'maquinas_equipamentos',
    title: 'Máquinas e Equipamentos',
    questions: [
      ChecklistQuestion(
        id: 'maquinas_ruidos',
        text: 'Possui ruídos estranhos na máquina?',
      ),
      ChecklistQuestion(
        id: 'maquinas_vazamento_ar',
        text: 'Existem vazamentos de ar/óleo nas mangueiras e engates rápidos?',
      ),
      ChecklistQuestion(
        id: 'maquinas_vazamento_outros',
        text: 'Existe vazamento de óleo/água/hidráulico e pneumático?',
      ),
      ChecklistQuestion(
        id: 'maquinas_mangueiras',
        text: 'As mangueiras estão em bom estado?',
      ),
      ChecklistQuestion(
        id: 'maquinas_nivel_oleo',
        text: 'O nível de óleo está correto?',
      ),
      ChecklistQuestion(
        id: 'maquinas_filtros',
        text: 'Os filtros estão limpos?',
      ),
      ChecklistQuestion(
        id: 'maquinas_itens_emergencia',
        text:
            'Os itens de emergência (botão, seta, luz gira-gira) estão funcionando?',
      ),
      ChecklistQuestion(
        id: 'maquinas_comandos_protecao',
        text: 'Os comandos estão com proteção e identificação?',
      ),
      ChecklistQuestion(
        id: 'maquinas_comandos_ruidos',
        text: 'Os comandos apresentam ruídos ou estão com problemas?',
      ),
      ChecklistQuestion(
        id: 'maquinas_leds',
        text: 'Os leds de sinalização estão funcionando?',
      ),
    ],
  ),
  ChecklistGroup(
    id: 'instrumentos_medicao',
    title: 'Instrumentos e Medição',
    questions: [
      ChecklistQuestion(
        id: 'instrumentos_recursos',
        text:
            'Todos os recursos de medição necessários estão disponíveis na máquina?',
      ),
      ChecklistQuestion(
        id: 'instrumentos_centesimal',
        text: 'Para dispositivos com relógio centesimal está partindo do 70?',
      ),
      ChecklistQuestion(
        id: 'instrumentos_milesimal',
        text:
            'Para dispositivos com relógio milesimal está partindo do 0 com o padrão?',
      ),
      ChecklistQuestion(
        id: 'instrumentos_local_limpo',
        text: 'O local dos instrumentos de controle está limpo?',
      ),
      ChecklistQuestion(
        id: 'instrumentos_local_identificado',
        text: 'O local dos instrumentos de controle está identificado?',
      ),
    ],
  ),
];

class ChecklistLiberacaoPage extends StatefulWidget {
  const ChecklistLiberacaoPage({super.key});

  @override
  State<ChecklistLiberacaoPage> createState() => _ChecklistLiberacaoPageState();
}

class _ChecklistLiberacaoPageState extends State<ChecklistLiberacaoPage> {
  final _formKey = GlobalKey<FormState>();
  final _reController = TextEditingController();
  final Map<String, ChecklistAnswer?> _answers = {};

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _loadingMaquinas = false;
  bool _salvando = false;

  List<String> _grupos = const [];
  Map<String, List<String>> _maquinasPorGrupo = const {};

  String? _grupoSelecionado;
  String? _maquinaSelecionada;

  @override
  void initState() {
    super.initState();
    _carregarMaquinas();
  }

  @override
  void dispose() {
    _reController.dispose();
    super.dispose();
  }

  Future<void> _carregarMaquinas() async {
    setState(() => _loadingMaquinas = true);
    try {
      final lista = await MachineService().fetchMaquinas();
      final maquinasPorGrupo = <String, SplayTreeSet<String>>{};
      for (final maquina in lista) {
        final categoria = maquina.categoria.trim();
        if (categoria.isEmpty) continue;
        final codigo = maquina.codigo.trim();
        if (codigo.isEmpty) continue;
        maquinasPorGrupo.putIfAbsent(categoria, SplayTreeSet.new).add(codigo);
      }

      final gruposOrdenados = maquinasPorGrupo.keys.toList()..sort();
      final mapaOrdenado = {
        for (final entry in maquinasPorGrupo.entries)
          entry.key: entry.value.toList(growable: false),
      };

      setState(() {
        _grupos = gruposOrdenados;
        _maquinasPorGrupo = mapaOrdenado;
        if (_grupoSelecionado != null &&
            !_maquinasPorGrupo.containsKey(_grupoSelecionado)) {
          _grupoSelecionado = null;
          _maquinaSelecionada = null;
        } else if (_grupoSelecionado != null) {
          final maquinas = _maquinasPorGrupo[_grupoSelecionado];
          if (maquinas == null || !maquinas.contains(_maquinaSelecionada)) {
            _maquinaSelecionada = null;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Falha ao carregar máquinas: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loadingMaquinas = false);
      }
    }
  }

  void _showSnackBar(String message, {bool erro = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _atualizarResposta(String questionId, ChecklistAnswer value) {
    setState(() {
      _answers[questionId] = value;
    });
  }

  Widget _buildRadioCell(String questionId, ChecklistAnswer value) {
    return Center(
      child: Radio<ChecklistAnswer>(
        value: value,
        groupValue: _answers[questionId],
        onChanged: (answer) {
          if (answer != null) {
            _atualizarResposta(questionId, answer);
          }
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  DataRow _buildQuestionRow(ChecklistQuestion question) {
    return DataRow(
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(question.text),
          ),
        ),
        DataCell(_buildRadioCell(question.id, ChecklistAnswer.sim)),
        DataCell(_buildRadioCell(question.id, ChecklistAnswer.nao)),
        DataCell(_buildRadioCell(question.id, ChecklistAnswer.naoAplica)),
      ],
    );
  }

  Widget _buildGroupCard(ChecklistGroup group, BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Pergunta')),
                  DataColumn(label: Text('Sim')),
                  DataColumn(label: Text('Não')),
                  DataColumn(label: Text('N/A')),
                ],
                rows: group.questions.map(_buildQuestionRow).toList(),
                headingRowColor: MaterialStateProperty.resolveWith(
                  (states) => Theme.of(context).colorScheme.surfaceVariant,
                ),
                horizontalMargin: 12,
                columnSpacing: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _maquinasDisponiveis {
    if (_grupoSelecionado == null) return const [];
    return _maquinasPorGrupo[_grupoSelecionado] ?? const [];
  }

  Future<void> _salvar() async {
    final form = _formKey.currentState;
    if (form == null) return;
    setState(() => _autovalidateMode = AutovalidateMode.always);
    if (!form.validate()) {
      _showSnackBar('Preencha os dados obrigatórios antes de salvar.');
      return;
    }

    final unanswered = _checklistGroups
        .expand((group) => group.questions)
        .where((question) => _answers[question.id] == null);

    if (unanswered.isNotEmpty) {
      _showSnackBar('Responda todas as perguntas do checklist.');
      return;
    }

    final respostas = <Map<String, dynamic>>[];
    var ordem = 0;
    for (final group in _checklistGroups) {
      for (final question in group.questions) {
        final answer = _answers[question.id];
        if (answer == null) continue;
        respostas.add({
          'grupo': group.title,
          'pergunta': question.text,
          'resposta': answer.apiValue,
          'ordem': ordem,
        });
        ordem++;
      }
    }

    if (respostas.isEmpty) {
      _showSnackBar('Não há respostas válidas para salvar.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await ChecklistLiberacaoService().registrarChecklist(
        re: _reController.text.trim(),
        grupoMaquina: _grupoSelecionado!,
        maquina: _maquinaSelecionada!,
        respostas: respostas,
      );
      if (!mounted) return;
      _showSnackBar('Checklist registrado com sucesso!', erro: false);
      setState(() {
        _answers.clear();
        _reController.clear();
        _grupoSelecionado = null;
        _maquinaSelecionada = null;
        _autovalidateMode = AutovalidateMode.disabled;
      });
      form.reset();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      _showSnackBar('Falha ao registrar checklist: $message');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Checklist de liberação', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 880;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: isWide ? 240 : double.infinity,
                            child: TextFormField(
                              controller: _reController,
                              decoration: const InputDecoration(
                                labelText: 'RE',
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                final texto = (value ?? '').trim();
                                if (texto.isEmpty) {
                                  return 'Informe o RE';
                                }
                                if (!RegExp(r'^[0-9]+$').hasMatch(texto)) {
                                  return 'Informe apenas números';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 240 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _grupoSelecionado,
                              decoration: InputDecoration(
                                labelText: 'Grupo de máquinas',
                                border: const OutlineInputBorder(),
                                suffixIcon: _loadingMaquinas
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              items: _grupos
                                  .map(
                                    (grupo) => DropdownMenuItem(
                                      value: grupo,
                                      child: Text(grupo),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _loadingMaquinas
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _grupoSelecionado = value;
                                        _maquinaSelecionada = null;
                                      });
                                    },
                              validator: (value) {
                                if ((_grupos.isNotEmpty ||
                                        _grupoSelecionado != null) &&
                                    (value == null || value.isEmpty)) {
                                  return 'Selecione um grupo de máquinas';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 240 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _maquinaSelecionada,
                              decoration: const InputDecoration(
                                labelText: 'Máquina',
                                border: OutlineInputBorder(),
                              ),
                              items: _maquinasDisponiveis
                                  .map(
                                    (maquina) => DropdownMenuItem(
                                      value: maquina,
                                      child: Text(maquina),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _maquinasDisponiveis.isEmpty
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _maquinaSelecionada = value,
                                      );
                                    },
                              validator: (value) {
                                if (_maquinasDisponiveis.isEmpty) {
                                  return 'Selecione um grupo para listar as máquinas';
                                }
                                if (value == null || value.isEmpty) {
                                  return 'Selecione a máquina';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      for (final group in _checklistGroups) ...[
                        _buildGroupCard(group, context),
                        const SizedBox(height: 24),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: _salvando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _salvando ? 'Salvando...' : 'Salvar checklist',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
