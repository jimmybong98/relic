// lib/features/preparacao/presentation/preparacao_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:admin/features/preparacao/data/models.dart';
import 'package:admin/features/operador/data/repository_provider.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/features/operador/presentation/widgets/measurement_tile.dart';
import 'package:admin/features/shared/providers/search_flow_form_provider.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/utils/api_base_url.dart';
import 'package:admin/widgets/search_summary_card.dart';
import 'package:admin/widgets/window_bar.dart';
import 'package:admin/utils/string_utils.dart';
import 'package:admin/services/machine_service.dart';
import 'package:admin/models/machine.dart';

class PreparacaoPage extends ConsumerStatefulWidget {
  const PreparacaoPage({super.key});

  @override
  ConsumerState<PreparacaoPage> createState() => _PreparacaoPageState();
}

final medidasPreparadorControllerProvider =
    StateNotifierProvider.autoDispose<
      MedidasPreparadorController,
      AsyncValue<List<MedidaItem>>
    >((ref) {
      return MedidasPreparadorController(ref);
    });

class MedidasPreparadorController
    extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasPreparadorController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(preparadorRepositoryProvider);
      final itens = await repo.getMedidas(
        partnumber: partnumber,
        operacao: operacao,
      );

      // Zera status/medição – sem copyWith
      final normalizados = itens
          .map(
            (m) => MedidaItem(
              indice: m.indice,
              titulo: m.titulo,
              faixaTexto: m.faixaTexto,
              minimo: m.minimo,
              maximo: m.maximo,
              unidade: m.unidade,
              status: StatusMedida.pendente,
              medicao: null,
              observacao: m.observacao,
              periodicidade: m.periodicidade,
              instrumento: m.instrumento,
              dataInclusao: m.dataInclusao,
              tolerancias: m.tolerancias,
              contagens: m.contagens,
              anguloMinimo: m.anguloMinimo,
              anguloMaximo: m.anguloMaximo,
            ),
          )
          .toList();

      state = AsyncValue.data(normalizados);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setStatusAndMedicao(int index, StatusMedida status, String? medicao) {
    final current = [...(state.value ?? const <MedidaItem>[])];
    if (index < 0 || index >= current.length) return;
    final old = current[index];
    current[index] = MedidaItem(
      indice: old.indice,
      titulo: old.titulo,
      faixaTexto: old.faixaTexto,
      minimo: old.minimo,
      maximo: old.maximo,
      unidade: old.unidade,
      status: status,
      medicao: medicao,
      observacao: old.observacao,
      periodicidade: old.periodicidade,
      instrumento: old.instrumento,
      dataInclusao: old.dataInclusao,
      tolerancias: old.tolerancias,
      contagens: old.contagens,
      anguloMinimo: old.anguloMinimo,
      anguloMaximo: old.anguloMaximo,
    );
    state = AsyncValue.data(current);
  }

  void resetSelecoes() {
    final current = [...(state.value ?? const <MedidaItem>[])];
    for (var i = 0; i < current.length; i++) {
      final old = current[i];
      current[i] = MedidaItem(
        indice: old.indice,
        titulo: old.titulo,
        faixaTexto: old.faixaTexto,
        minimo: old.minimo,
        maximo: old.maximo,
        unidade: old.unidade,
        status: StatusMedida.pendente,
        medicao: null,
        observacao: old.observacao,
        periodicidade: old.periodicidade,
        instrumento: old.instrumento,
        dataInclusao: old.dataInclusao,
        tolerancias: old.tolerancias,
        contagens: old.contagens,
        anguloMinimo: old.anguloMinimo,
        anguloMaximo: old.anguloMaximo,
      );
    }
    state = AsyncValue.data(current);
  }
}

class _PreparacaoPageState extends ConsumerState<PreparacaoPage> {
  static const double _compactFormBreakpoint = 600;

  final _formKey = GlobalKey<FormState>();
  final _reCtrl = TextEditingController(); // <<< RE
  final _osCtrl = TextEditingController(); // <<< OS
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();

  final List<Machine> _maquinas = [];
  final List<String> _categorias = [];
  String? _categoriaSel;
  String? _maquinaSel;

  bool _registrando = false;
  bool _osLiberada = false;
  bool _mostrarResumo = false;

  late final VoidCallback _osSyncListener;
  late final VoidCallback _partSyncListener;
  late final VoidCallback _opSyncListener;

  void _resetLiberada() {
    if (_osLiberada) setState(() => _osLiberada = false);
  }

  @override
  void initState() {
    super.initState();
    final shared = ref.read(sharedSearchFormProvider);
    if (shared.isActive) {
      _osCtrl.text = shared.os;
      _partCtrl.text = shared.partNumber;
      _opCtrl.text = shared.operacao;
      _categoriaSel = shared.categoria;
      _maquinaSel = shared.maquina;
    }

    _osSyncListener = () {
      ref.read(sharedSearchFormProvider.notifier).setOs(_osCtrl.text);
    };
    _partSyncListener = () {
      ref.read(sharedSearchFormProvider.notifier).setPartNumber(_partCtrl.text);
    };
    _opSyncListener = () {
      ref.read(sharedSearchFormProvider.notifier).setOperacao(_opCtrl.text);
    };

    _osCtrl.addListener(_resetLiberada);
    _partCtrl.addListener(_resetLiberada);
    _opCtrl.addListener(_resetLiberada);

    _osCtrl.addListener(_osSyncListener);
    _partCtrl.addListener(_partSyncListener);
    _opCtrl.addListener(_opSyncListener);
    _carregarMaquinas();
  }

  Future<void> _carregarMaquinas() async {
    try {
      final list = await MachineService().fetchMaquinas();
      if (mounted) {
        setState(() {
          _maquinas
            ..clear()
            ..addAll(list);
          _categorias
            ..clear()
            ..addAll(
              _maquinas.map((e) => e.categoria).toSet().toList()..sort(),
            );
          final notifier = ref.read(sharedSearchFormProvider.notifier);
          final categoriaAtual = _categoriaSel;
          if (categoriaAtual != null && !_categorias.contains(categoriaAtual)) {
            _categoriaSel = null;
            notifier.setCategoria(null);
          }

          if (_categoriaSel != null) {
            final possuiMaquina = _maquinas.any(
              (m) => m.categoria == _categoriaSel && m.codigo == _maquinaSel,
            );
            if (!possuiMaquina && _maquinaSel != null) {
              _maquinaSel = null;
              notifier.setMaquina(null);
            }
          } else if (_maquinaSel != null) {
            _maquinaSel = null;
            notifier.setMaquina(null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar máquinas: $e')),
        );
      }
    }
  }

  bool _flowMatchesCurrentForm(SharedSearchFormState shared) {
    if (!shared.isActive) return true;
    return shared.matchesValues(
      os: _osCtrl.text,
      partNumber: _partCtrl.text,
      operacao: _opCtrl.text,
      categoria: _categoriaSel,
      maquina: _maquinaSel,
    );
  }

  void _showFlowBlockedSnackBar(SharedSearchFormState shared) {
    if (!mounted) return;
    final osAtual = shared.os.trim();
    final mensagem = osAtual.isEmpty
        ? 'Finalize a O.S. em andamento antes de iniciar outra.'
        : 'Finalize a O.S. $osAtual antes de iniciar outra.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  bool _ensureFlowConsistency() {
    final shared = ref.read(sharedSearchFormProvider);
    if (_flowMatchesCurrentForm(shared)) {
      return true;
    }
    _showFlowBlockedSnackBar(shared);
    return false;
  }

  Future<void> _abrirPaginaOperador() async {
    if (!_ensureFlowConsistency()) return;

    final notifier = ref.read(sharedSearchFormProvider.notifier);
    final iniciouFluxo = notifier.beginFlow(
      os: _osCtrl.text,
      partNumber: _partCtrl.text,
      operacao: _opCtrl.text,
      categoria: _categoriaSel,
      maquina: _maquinaSel,
      process: SearchFlowProcess.amostragem,
    );

    if (!iniciouFluxo) {
      _showFlowBlockedSnackBar(ref.read(sharedSearchFormProvider));
      return;
    }

    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const OperadorPage()));
  }

  @override
  void dispose() {
    _osCtrl.removeListener(_resetLiberada);
    _partCtrl.removeListener(_resetLiberada);
    _opCtrl.removeListener(_resetLiberada);
    _osCtrl.removeListener(_osSyncListener);
    _partCtrl.removeListener(_partSyncListener);
    _opCtrl.removeListener(_opSyncListener);
    _reCtrl.dispose();
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
  }

  String statusToString(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return 'OK';
      case StatusMedida.reprovadaAbaixo:
        return 'Reprovada abaixo';
      case StatusMedida.reprovadaAcima:
        return 'Reprovada acima';
      case StatusMedida.alertaAbaixo:
        return 'Alerta abaixo';
      case StatusMedida.alertaAcima:
        return 'Alerta acima';
      case StatusMedida.pendente:
        return 'pendente';
    }
  }

  Future<void> _registrarResultado() async {
    final medidas = ref.read(medidasPreparadorControllerProvider).value ?? [];

    // Valida RE / OS
    if (_reCtrl.text.trim().isEmpty ||
        _osCtrl.text.trim().isEmpty ||
        (_maquinaSel ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha RE, O.S. e máquina para registrar.'),
        ),
      );
      return;
    }

    if (!_ensureFlowConsistency()) return;

    // Todas respondidas? (para Preparador, cada item precisa de medição)
    final faltando = <int>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      if ((m.medicao == null || m.medicao!.isEmpty) ||
          m.status == StatusMedida.pendente) {
        faltando.add(i);
      }
    }
    if (faltando.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltam ${faltando.length} medições para preencher.'),
        ),
      );
      return;
    }

    // Verifica se há alguma medida reprovada
    final reprovadas = medidas
        .where(
          (m) =>
              m.status == StatusMedida.reprovadaAbaixo ||
              m.status == StatusMedida.reprovadaAcima,
        )
        .toList();
    if (reprovadas.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uma ou mais medidas foram reprovadas.')),
      );
      return;
    }

    // Monta payload
    final itens = <Map<String, dynamic>>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      itens.add({
        'indice': m.indice ?? i,
        'titulo': m.titulo,
        'faixaTexto': m.faixaTexto,
        'min': m.minimo,
        'max': m.maximo,
        'unidade': m.unidade,
        'medicao': m.medicao, // valor digitado
        'status': statusToString(m.status),
        'observacao': m.observacao ?? '',
      });
    }

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': normalizeCode(_partCtrl.text),
      'operacao': normalizeCode(_opCtrl.text),
      'maquina': _maquinaSel,
      'itens': itens,
    });

    final uri = buildApiUri('/preparador/resultado');

    setState(() => _registrando = true);
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final statusGeral = (data['status_geral'] ?? '')
            .toString()
            .toLowerCase();
        final liberada = statusGeral == 'liberada';
        if (liberada) {
          setState(() => _osLiberada = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resultado registrado com sucesso!')),
        );
        ref.read(medidasPreparadorControllerProvider.notifier).resetSelecoes();
        if (liberada) {
          await _abrirPaginaOperador();
        }
      } else if (resp.statusCode == 409) {
        final data = jsonDecode(resp.body);
        final liberada = (data['code'] ?? '') == 'ja_liberada';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao registrar: ${data['error'] ?? resp.body}'),
          ),
        );
        if (liberada) {
          setState(() => _osLiberada = true);
          await _abrirPaginaOperador();
        }
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
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasPreparadorControllerProvider);
    final medidas = medidasAsync.value ?? [];
    final dataRevisao = medidas.firstDataInclusao != null
        ? DateFormat('dd/MM/yyyy').format(medidas.firstDataInclusao!.toLocal())
        : null;
    final flowState = ref.watch(sharedSearchFormProvider);
    final flowLocked = flowState.isActive;
    final flowProcessName = flowState.processDisplayName;
    final flowOs = flowState.os.trim();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final actionBottomPadding = bottomInset > 0 ? bottomInset + 16.0 : 16.0;

    // Pode registrar quando: RE e OS preenchidos + todas as medições preenchidas
    final reOk = _reCtrl.text.trim().isNotEmpty;
    final osOk = _osCtrl.text.trim().isNotEmpty;
    final categoriaValue =
        (_categoriaSel != null && _categorias.contains(_categoriaSel))
        ? _categoriaSel
        : null;
    final maquinasDisponiveis = _maquinas
        .where((m) => m.categoria == categoriaValue)
        .toList();
    final maquinaValue =
        (_maquinaSel != null &&
            maquinasDisponiveis.any((m) => m.codigo == _maquinaSel))
        ? _maquinaSel
        : null;
    final maquinaOk = (maquinaValue ?? '').isNotEmpty;
    final formMatchesFlow =
        !flowLocked ||
        flowState.matchesValues(
          os: _osCtrl.text,
          partNumber: _partCtrl.text,
          operacao: _opCtrl.text,
          categoria: categoriaValue,
          maquina: maquinaValue,
        );
    final todasOk =
        medidas.isNotEmpty &&
        medidas.every(
          (m) =>
              (m.medicao ?? '').isNotEmpty && m.status != StatusMedida.pendente,
        );
    final podeRegistrar =
        formMatchesFlow &&
        reOk &&
        osOk &&
        maquinaOk &&
        todasOk &&
        !_registrando &&
        !_osLiberada;

    return Scaffold(
      appBar: WindowBar(
        title: 'Liberação de Máquina - FOR007',
        titleSvgAsset: 'assets/icons/go.svg',
        showMenu: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                Platform.isWindows
                    ? 'Windows: leitura direta/API'
                    : 'Android: via API',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      drawer: const SideMenu(current: SideMenuSection.preparador),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (flowLocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                flowOs.isEmpty
                                    ? 'Existe um fluxo de $flowProcessName em andamento. Finalize a O.S. atual para iniciar outra.'
                                    : 'Fluxo de $flowProcessName ativo para a O.S. $flowOs. Finalize a O.S. atual para iniciar outra.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_mostrarResumo) ...[
                      SearchSummaryCard(
                        reLabel: 'R.E. do Preparador',
                        reValue: _reCtrl.text,
                        items: [
                          SummaryInfo(label: 'O.S.', value: _osCtrl.text),
                          SummaryInfo(label: 'Peça', value: _partCtrl.text),
                          SummaryInfo(label: 'Operação', value: _opCtrl.text),
                          if (dataRevisao != null)
                            SummaryInfo(
                              label: 'Data de revisão',
                              value: dataRevisao,
                            ),
                          if ((maquinaValue ?? '').isNotEmpty)
                            SummaryInfo(label: 'Máquina', value: maquinaValue!),
                          if ((categoriaValue ?? '').isNotEmpty)
                            SummaryInfo(
                              label: 'Grupo de máquina',
                              value: categoriaValue!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _mostrarResumo = false);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Alterar dados da busca'),
                        ),
                      ),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact =
                                    constraints.maxWidth <
                                    _compactFormBreakpoint;
                                final reField = TextFormField(
                                  controller: _reCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'R.E. do Preparador',
                                    border: OutlineInputBorder(),
                                  ),
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Obrigatório';
                                    if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                      return 'Apenas números';
                                    }
                                    return null;
                                  },
                                );
                                final osField = TextFormField(
                                  controller: _osCtrl,
                                  enabled: !flowLocked,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'O.S.',
                                    border: OutlineInputBorder(),
                                  ),
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Obrigatório';
                                    if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                      return 'Apenas números';
                                    }
                                    return null;
                                  },
                                );
                                if (isCompact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      reField,
                                      const SizedBox(height: 12),
                                      osField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: reField),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 140, // igual ao campo Operação
                                      child: osField,
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact =
                                    constraints.maxWidth <
                                    _compactFormBreakpoint;
                                final categoriaDropdown =
                                    DropdownButtonFormField<String>(
                                      value: categoriaValue,
                                      decoration: const InputDecoration(
                                        labelText: 'Grupo de máquina',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _categorias
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: flowLocked
                                          ? null
                                          : (v) {
                                              ref
                                                  .read(
                                                    sharedSearchFormProvider
                                                        .notifier,
                                                  )
                                                  .setCategoria(v);
                                              setState(() {
                                                _categoriaSel = v;
                                                _maquinaSel = null;
                                              });
                                            },
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Obrigatório'
                                          : null,
                                    );
                                final maquinaDropdown =
                                    DropdownButtonFormField<String>(
                                      value: maquinaValue,
                                      decoration: const InputDecoration(
                                        labelText: 'Código da máquina',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: maquinasDisponiveis
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m.codigo,
                                              child: Text(m.codigo),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: flowLocked
                                          ? null
                                          : (v) {
                                              ref
                                                  .read(
                                                    sharedSearchFormProvider
                                                        .notifier,
                                                  )
                                                  .setMaquina(v);
                                              setState(() => _maquinaSel = v);
                                            },
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Obrigatório'
                                          : null,
                                    );

                                if (isCompact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      categoriaDropdown,
                                      const SizedBox(height: 12),
                                      maquinaDropdown,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: categoriaDropdown),
                                    const SizedBox(width: 12),
                                    Expanded(child: maquinaDropdown),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // ---------- PartNumber + Operação (Operação só números) ----------
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact =
                                    constraints.maxWidth <
                                    _compactFormBreakpoint;
                                final partField = TextFormField(
                                  controller: _partCtrl,
                                  enabled: !flowLocked,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Código da peça',
                                    border: OutlineInputBorder(),
                                  ),
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Obrigatório'
                                      : null,
                                );
                                final operacaoField = TextFormField(
                                  controller: _opCtrl,
                                  enabled: !flowLocked,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Operação',
                                    border: OutlineInputBorder(),
                                  ),
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Obrigatório';
                                    if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                      return 'Apenas números';
                                    }
                                    return null;
                                  },
                                );

                                if (isCompact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      partField,
                                      const SizedBox(height: 12),
                                      operacaoField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: partField),
                                    const SizedBox(width: 12),
                                    SizedBox(width: 140, child: operacaoField),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    if (!_ensureFlowConsistency()) return;
                                    FocusScope.of(context).unfocus();
                                    await ref
                                        .read(
                                          medidasPreparadorControllerProvider
                                              .notifier,
                                        )
                                        .carregar(
                                          partnumber: normalizeCode(
                                            _partCtrl.text,
                                          ),
                                          operacao: normalizeCode(_opCtrl.text),
                                        );
                                    if (mounted) {
                                      setState(() => _mostrarResumo = true);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Carregar medidas'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              ..._buildMedidasSlivers(medidasAsync),
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: actionBottomPadding),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: podeRegistrar
                                ? _registrarResultado
                                : null,
                            icon: _registrando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Registrar resultado'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMedidasSlivers(AsyncValue<List<MedidaItem>> medidasAsync) {
    return medidasAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhuma medida encontrada para a chave informada.',
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ];
        }
        return [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = list[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == list.length - 1 ? 0 : 8,
                ),
                child: MeasurementTile(
                  index: index,
                  item: item,
                  manualEntry: true,
                  onSelect: (status, medicao) => ref
                      .read(medidasPreparadorControllerProvider.notifier)
                      .setStatusAndMedicao(index, status, medicao),
                ),
              );
            }, childCount: list.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ];
      },
      loading: () => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Erro ao carregar:\n${e.toString()}')),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
      ],
    );
  }
}
