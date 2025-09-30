import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:admin/features/operador/presentation/widgets/measurement_tile.dart';
import 'package:admin/features/preparacao/data/models.dart';
import 'package:admin/utils/api_base_url.dart';
import 'package:admin/utils/string_utils.dart';

class TrocaFerramentaPage extends StatefulWidget {
  final String re;
  final String os;
  final String partnumber;
  final String operacao;
  final String maquina;

  const TrocaFerramentaPage({
    super.key,
    required this.re,
    required this.os,
    required this.partnumber,
    required this.operacao,
    required this.maquina,
  });

  @override
  State<TrocaFerramentaPage> createState() => _TrocaFerramentaPageState();
}

class _TrocaFerramentaPageState extends State<TrocaFerramentaPage> {
  late final TextEditingController _reController;
  bool _loading = true;
  String? _erro;
  List<MedidaItem> _todas = [];
  Set<int> _selecionadas = <int>{};
  List<MedidaItem> _medidasSelecionadas = [];
  bool _medindo = false;
  bool _registrando = false;
  String? _dataRevisao;

  @override
  void initState() {
    super.initState();
    _reController = TextEditingController(text: widget.re);
    _carregarMedidas();
  }

  @override
  void dispose() {
    _reController.dispose();
    super.dispose();
  }

  Future<void> _carregarMedidas() async {
    setState(() {
      _loading = true;
      _erro = null;
      _dataRevisao = null;
    });

    final uri = buildApiUri('/preparador/medidas', {
      'partnumber': normalizeCode(widget.partnumber),
      'operacao': normalizeCode(widget.operacao),
    });

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = resp.body.isEmpty ? '[]' : resp.body;
        final data = jsonDecode(body);
        final itens = data is List
            ? data
                  .map<MedidaItem>(
                    (e) =>
                        MedidaItem.fromMap((e as Map).cast<String, dynamic>()),
                  )
                  .toList()
            : <MedidaItem>[];
        final dataInclusao = itens.firstDataInclusao;
        final dataFormatada = dataInclusao != null
            ? DateFormat('dd/MM/yyyy').format(dataInclusao.toLocal())
            : null;
        setState(() {
          _todas = itens;
          _selecionadas = <int>{};
          _medidasSelecionadas = [];
          _medindo = false;
          _loading = false;
          _dataRevisao = dataFormatada;
        });
      } else if (resp.statusCode == 404 || resp.statusCode == 204) {
        setState(() {
          _todas = [];
          _selecionadas = <int>{};
          _medidasSelecionadas = [];
          _medindo = false;
          _loading = false;
          _dataRevisao = null;
        });
      } else {
        throw Exception('Falha ao carregar (${resp.statusCode}) ${resp.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
        _dataRevisao = null;
      });
    }
  }

  void _toggleSelecao(int index, bool? value) {
    setState(() {
      if (value == true) {
        _selecionadas.add(index);
      } else {
        _selecionadas.remove(index);
      }
    });
  }

  void _avancarParaMedicao() {
    if (_selecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma medida.')),
      );
      return;
    }

    final ordenadas = _selecionadas.toList()..sort();
    final selecionadas = ordenadas.map((idx) {
      final item = _todas[idx];
      return MedidaItem(
        indice: item.indice,
        titulo: item.titulo,
        faixaTexto: item.faixaTexto,
        minimo: item.minimo,
        maximo: item.maximo,
        unidade: item.unidade,
        status: StatusMedida.pendente,
        medicao: null,
        observacao: item.observacao,
        periodicidade: item.periodicidade,
        instrumento: item.instrumento,
        dataInclusao: item.dataInclusao,
        tolerancias: item.tolerancias,
        contagens: item.contagens,
        anguloMinimo: item.anguloMinimo,
        anguloMaximo: item.anguloMaximo,
      );
    }).toList();

    setState(() {
      _medidasSelecionadas = selecionadas;
      _medindo = true;
    });
  }

  void _atualizarMedicao(int index, StatusMedida status, String? medicao) {
    final itens = [..._medidasSelecionadas];
    if (index < 0 || index >= itens.length) return;
    final antigo = itens[index];
    itens[index] = MedidaItem(
      indice: antigo.indice,
      titulo: antigo.titulo,
      faixaTexto: antigo.faixaTexto,
      minimo: antigo.minimo,
      maximo: antigo.maximo,
      unidade: antigo.unidade,
      status: status,
      medicao: medicao,
      observacao: antigo.observacao,
      periodicidade: antigo.periodicidade,
      instrumento: antigo.instrumento,
      dataInclusao: antigo.dataInclusao,
      tolerancias: antigo.tolerancias,
      contagens: antigo.contagens,
      anguloMinimo: antigo.anguloMinimo,
      anguloMaximo: antigo.anguloMaximo,
    );
    setState(() {
      _medidasSelecionadas = itens;
    });
  }

  String _subtitleFor(MedidaItem item) {
    if (item.faixaTexto.isNotEmpty) return item.faixaTexto;
    final min = item.minimo;
    final max = item.maximo;
    final uni = (item.unidade ?? '').isNotEmpty ? ' ${item.unidade}' : '';
    if (min != null && max != null) {
      return '${min.toStringAsFixed(2)} – ${max.toStringAsFixed(2)}$uni';
    }
    if (min != null) {
      return '≥ ${min.toStringAsFixed(2)}$uni';
    }
    if (max != null) {
      return '≤ ${max.toStringAsFixed(2)}$uni';
    }
    return '';
  }

  String _observacaoComContexto(String? original) {
    const marcador = 'Troca de ferramenta';
    final atual = (original ?? '').trim();
    if (atual.isEmpty) return marcador;
    final lowerAtual = atual.toLowerCase();
    if (lowerAtual.contains(marcador.toLowerCase())) return atual;
    return '$marcador | $atual';
  }

  Future<void> _registrarMedicoes() async {
    if (_registrando) return;
    if (_medidasSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma medida selecionada.')),
      );
      return;
    }
    final reAtual = _reController.text.trim();
    if (reAtual.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o R.E. de quem está medindo.')),
      );
      return;
    }
    if (int.tryParse(reAtual) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O R.E. deve conter apenas números.')),
      );
      return;
    }
    final pendentes = _medidasSelecionadas.where(
      (m) =>
          m.status == StatusMedida.pendente ||
          (m.medicao == null || m.medicao!.trim().isEmpty),
    );
    if (pendentes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todas as medições selecionadas.'),
        ),
      );
      return;
    }

    final naoAprovadas = _medidasSelecionadas.where(
      (m) => m.status != StatusMedida.ok,
    );
    if (naoAprovadas.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas as medições devem estar aprovadas.'),
        ),
      );
      return;
    }

    final itens = <Map<String, dynamic>>[];
    for (var i = 0; i < _medidasSelecionadas.length; i++) {
      final m = _medidasSelecionadas[i];
      itens.add({
        'indice': m.indice ?? i,
        'titulo': m.titulo,
        'faixaTexto': m.faixaTexto,
        'min': m.minimo,
        'max': m.maximo,
        'unidade': m.unidade,
        'medicao': m.medicao ?? '',
        'status': statusToString(m.status),
        'observacao': _observacaoComContexto(m.observacao),
        'periodicidade': m.periodicidade ?? '',
        'instrumento': m.instrumento ?? '',
        'tolerancias': m.tolerancias,
      });
    }

    final uri = buildApiUri('/preparador/resultado');
    final body = jsonEncode({
      're': reAtual,
      'os': widget.os,
      'partnumber': normalizeCode(widget.partnumber),
      'operacao': normalizeCode(widget.operacao),
      'maquina': widget.maquina,
      'contexto': 'troca_ferramenta',
      'itens': itens,
    });

    setState(() => _registrando = true);
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medições registradas com sucesso.')),
        );
        Navigator.of(context).pop(true);
      } else if (resp.statusCode == 409) {
        final data = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error']?.toString() ?? 'Conflito ao registrar medições.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao registrar: ${resp.statusCode} ${resp.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao registrar: $e')));
    } finally {
      if (mounted) {
        setState(() => _registrando = false);
      }
    }
  }

  void _onBack() {
    if (_medindo) {
      setState(() {
        _medindo = false;
        _medidasSelecionadas = [];
      });
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Widget _buildEditableReChip() {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('R.E.', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _reController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Informe o R.E.',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            onEditingComplete: () => FocusScope.of(context).unfocus(),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_medindo) {
          _onBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Troca de ferramenta'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBack,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Erro ao carregar medidas:\n${_erro!}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _carregarMedidas,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            _buildEditableReChip(),
                            _buildInfoChip('O.S.', widget.os),
                            _buildInfoChip('Peça', widget.partnumber),
                            _buildInfoChip('Operação', widget.operacao),
                            if (_dataRevisao != null)
                              _buildInfoChip('Data de revisão', _dataRevisao!),
                            _buildInfoChip('Máquina', widget.maquina),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_medindo) ...[
                      Text(
                        'Selecione as medidas impactadas pela troca da ferramenta.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _todas.isEmpty
                            ? const Center(
                                child: Text('Nenhuma medida disponível.'),
                              )
                            : ListView.separated(
                                itemCount: _todas.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _todas[index];
                                  final selecionado = _selecionadas.contains(
                                    index,
                                  );
                                  final subtitulo = _subtitleFor(item);
                                  return CheckboxListTile(
                                    value: selecionado,
                                    onChanged: (value) =>
                                        _toggleSelecao(index, value),
                                    title: Text(
                                      item.titulo.isEmpty
                                          ? '(sem título)'
                                          : item.titulo,
                                    ),
                                    subtitle: subtitulo.isEmpty
                                        ? null
                                        : Text(subtitulo),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _selecionadas.isEmpty
                              ? null
                              : _avancarParaMedicao,
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text('Prosseguir para medição (FOR07)'),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Realize as medições selecionadas (FOR07).',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FocusTraversalGroup(
                          policy: OrderedTraversalPolicy(),
                          child: ListView.builder(
                            itemCount: _medidasSelecionadas.length,
                            itemBuilder: (context, index) {
                              final item = _medidasSelecionadas[index];
                              return MeasurementTile(
                                index: index,
                                item: item,
                                manualEntry: true,
                                onSelect: (status, medicao) =>
                                    _atualizarMedicao(index, status, medicao),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _registrando ? null : _registrarMedicoes,
                          icon: _registrando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Registrar medições'),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
