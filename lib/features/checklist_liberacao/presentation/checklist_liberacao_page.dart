import 'package:flutter/material.dart';

import '../../../screens/main/components/side_menu.dart';
import '../../../widgets/window_bar.dart';

enum ChecklistAnswer { sim, nao, naoAplica }

class ChecklistLiberacaoPage extends StatefulWidget {
  const ChecklistLiberacaoPage({super.key});

  @override
  State<ChecklistLiberacaoPage> createState() => _ChecklistLiberacaoPageState();
}

class _ChecklistLiberacaoPageState extends State<ChecklistLiberacaoPage> {
  final _reController = TextEditingController();
  final _maquinaController = TextEditingController();

  final _questions = const [
    'Todos recursos de medição necessários estão disponível na maquina ?',
    'Para dispositivos com relógio centesimal esta partindo do 70 ?',
    'Para dispositivos com relógio milesimal está partindo do 0 com o padrão?',
    'Local dos instrumentos de controle está limpo?',
  ];

  final Map<int, ChecklistAnswer?> _answers = {};

  @override
  void dispose() {
    _reController.dispose();
    _maquinaController.dispose();
    super.dispose();
  }

  void _updateAnswer(int index, ChecklistAnswer value) {
    setState(() {
      _answers[index] = value;
    });
  }

  Widget _buildAnswerOption(int index, ChecklistAnswer value, String label) {
    return RadioListTile<ChecklistAnswer>(
      value: value,
      groupValue: _answers[index],
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      onChanged: (answer) {
        if (answer != null) {
          _updateAnswer(index, answer);
        }
      },
    );
  }

  DataRow _buildQuestionRow(int index, String question) {
    return DataRow(
      cells: [
        DataCell(Text(question)),
        DataCell(_buildAnswerOption(index, ChecklistAnswer.sim, 'Sim')),
        DataCell(_buildAnswerOption(index, ChecklistAnswer.nao, 'Não')),
        DataCell(_buildAnswerOption(index, ChecklistAnswer.naoAplica, 'N/A')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Checklist de liberação', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isWide ? 250 : double.infinity,
                          child: TextField(
                            controller: _reController,
                            decoration: const InputDecoration(
                              labelText: 'RE',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 250 : double.infinity,
                          child: TextField(
                            controller: _maquinaController,
                            decoration: const InputDecoration(
                              labelText: 'Máquina',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instrumentos e Medição',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                                rows: [
                                  for (var i = 0; i < _questions.length; i++)
                                    _buildQuestionRow(i, _questions[i]),
                                ],
                                headingRowColor:
                                    MaterialStateProperty.resolveWith(
                                      (states) => Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
