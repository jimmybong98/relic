// lib/features/finalizar_os/presentation/finalizar_os_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:admin/features/preparacao/data/models.dart';
import 'package:admin/features/preparacao/data/repository_provider.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import 'package:admin/utils/string_utils.dart';
import 'package:admin/services/machine_service.dart';
import 'package:admin/models/machine.dart';

/// Mesmo base URL usado no Operador
const String kBaseUrl = 'http://192.168.0.241:5005';

class FinalizarOsPage extends ConsumerStatefulWidget {
  const FinalizarOsPage({super.key});

  @override
  ConsumerState<FinalizarOsPage> createState() => _FinalizarOsPageState();
}

final medidasFinalizadorControllerProvider =
    StateNotifierProvider.autoDispose<
      MedidasFinalizadorController,
      AsyncValue<List<MedidaItem>>
    >((ref) {
      return MedidasFinalizadorController(ref);
    });

class MedidasFinalizadorController
    extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasFinalizadorController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(finalizadorRepositoryProvider);
      final itens = await repo.getMedidas(
        partnumber: partnumber,
        operacao: operacao,
      );

      // Zera status/medição – sem copyWith
      final normalizados = itens
          .map(
            (m) => MedidaItem(
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
              tolerancias: m.tolerancias,
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
      tolerancias: old.tolerancias,
    );
    state = AsyncValue.data(current);
  }

  void resetSelecoes() {
    final current = [...(state.value ?? const <MedidaItem>[])];
    for (var i = 0; i < current.length; i++) {
      final old = current[i];
      current[i] = MedidaItem(
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
        tolerancias: old.tolerancias,
      );
    }
    state = AsyncValue.data(current);
  }
}

class _FinalizarOsPageState extends ConsumerState<FinalizarOsPage> {
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
  bool _osFinalizada = false;

  void _resetFinalizada() {
    if (_osFinalizada) setState(() => _osFinalizada = false);
  }

  @override
  void initState() {
    super.initState();
    _osCtrl.addListener(_resetFinalizada);
    _partCtrl.addListener(_resetFinalizada);
    _opCtrl.addListener(_resetFinalizada);
    _carregarMaquinas();
  }

  Future<void> _carregarMaquinas() async {
    try {
      final list = await MachineService().fetchMaquinas();
      if (mounted) {
        setState(() {
          _maquinas.addAll(list);
          _categorias.addAll(
            _maquinas.map((e) => e.categoria).toSet().toList()..sort(),
          );
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

  @override
  void dispose() {
    _osCtrl.removeListener(_resetFinalizada);
    _partCtrl.removeListener(_resetFinalizada);
    _opCtrl.removeListener(_resetFinalizada);
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

  Future<void> _registrarFinalizacao() async {
    final medidas = ref.read(medidasFinalizadorControllerProvider).value ?? [];

    // Valida RE / OS / Máquina
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
        'indice': i,
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

    final uri = Uri.parse('$kBaseUrl/preparador/finalizar_os');

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
        if (statusGeral.isNotEmpty) {
          setState(() => _osFinalizada = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OS finalizada com sucesso!')),
        );
        ref.read(medidasFinalizadorControllerProvider.notifier).resetSelecoes();
      } else if (resp.statusCode == 409) {
        final data = jsonDecode(resp.body);
        if ((data['code'] ?? '') == 'ja_finalizada') {
          setState(() => _osFinalizada = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao registrar: ${data['error'] ?? resp.body}'),
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
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasFinalizadorControllerProvider);
    final medidas = medidasAsync.value ?? [];

    // Pode registrar quando: RE e OS preenchidos + todas as medições preenchidas
    final reOk = _reCtrl.text.trim().isNotEmpty;
    final osOk = _osCtrl.text.trim().isNotEmpty;
    final maquinaOk = (_maquinaSel ?? '').isNotEmpty;
    final todasOk =
        medidas.isNotEmpty &&
        medidas.every(
          (m) =>
              (m.medicao ?? '').isNotEmpty && m.status != StatusMedida.pendente,
        );
    final podeRegistrar =
        reOk && osOk && maquinaOk && todasOk && !_registrando && !_osFinalizada;

    return Scaffold(
      appBar: WindowBar(
        title: 'Finalizar OS',
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
      drawer: const SideMenu(current: SideMenuSection.finalizar),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _reCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText:
                                  'R.E. do Preparador', // ajuste o texto se for Operador
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s))
                                return 'Apenas números';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140, // igual ao campo Operação
                          child: TextFormField(
                            controller: _osCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'O.S.',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s))
                                return 'Apenas números';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoriaSel,
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
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
                            onChanged: (v) => setState(() {
                              _categoriaSel = v;
                              _maquinaSel = null;
                            }),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _maquinaSel,
                            decoration: const InputDecoration(
                              labelText: 'Código da máquina',
                              border: OutlineInputBorder(),
                            ),
                            items: _maquinas
                                .where((m) => m.categoria == _categoriaSel)
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.codigo,
                                    child: Text(m.codigo),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _maquinaSel = v),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Obrigatório' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ---------- PartNumber + Operação (Operação só números) ----------
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _partCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Código da peça (PartNumber)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            controller: _opCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Operação',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s))
                                return 'Apenas números';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            FocusScope.of(context).unfocus();
                            await ref
                                .read(
                                  medidasFinalizadorControllerProvider.notifier,
                                )
                                .carregar(
                                  partnumber: normalizeCode(_partCtrl.text),
                                  operacao: normalizeCode(_opCtrl.text),
                                );
                          }
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Carregar medidas'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: medidasAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma medida encontrada para a chave informada.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _MeasurementTilePrep(
                          index: index,
                          item: item,
                          onChanged: (status, valor) => ref
                              .read(
                                medidasFinalizadorControllerProvider.notifier,
                              )
                              .setStatusAndMedicao(index, status, valor),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Erro ao carregar:\n${e.toString()}')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: podeRegistrar ? _registrarFinalizacao : null,
                  icon: _registrando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Finalizar OS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementTilePrep extends StatefulWidget {
  final int index;
  final MedidaItem item;
  final void Function(StatusMedida status, String valor) onChanged;

  const _MeasurementTilePrep({
    required this.index,
    required this.item,
    required this.onChanged,
  });

  @override
  State<_MeasurementTilePrep> createState() => _MeasurementTilePrepState();
}

class _MeasurementTilePrepState extends State<_MeasurementTilePrep> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setTextFromParent(widget.item.medicao);
  }

  @override
  void didUpdateWidget(covariant _MeasurementTilePrep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // só atualiza o controller quando o valor vindo do pai REALMENTE mudou
    if (oldWidget.item.medicao != widget.item.medicao) {
      _setTextFromParent(widget.item.medicao);
    }
  }

  void _setTextFromParent(String? txt) {
    final newText = (txt ?? '');
    if (newText == _ctrl.text)
      return; // evita sobrescrever e mexer no cursor à toa
    _ctrl.value = TextEditingValue(
      text: newText,
      // cursor no final do texto (sem selecionar tudo)
      selection: TextSelection.collapsed(offset: newText.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? _toDouble(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  StatusMedida _classifica(double? v, double? min, double? max) {
    if (v == null) return StatusMedida.pendente;
    if (min != null && v < min) return StatusMedida.reprovadaAbaixo;
    if (max != null && v > max) return StatusMedida.reprovadaAcima;
    return StatusMedida.ok;
  }

  Color _statusColor(StatusMedida st) {
    switch (st) {
      case StatusMedida.ok:
        return Colors.green.shade600;
      case StatusMedida.reprovadaAbaixo:
        return Colors.red.shade400;
      case StatusMedida.reprovadaAcima:
        return Colors.red.shade400;
      case StatusMedida.alertaAbaixo:
      case StatusMedida.alertaAcima:
        return Colors.amber.shade700;
      case StatusMedida.pendente:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;

    String subtitulo = m.faixaTexto;
    if (subtitulo.isEmpty && (m.minimo != null || m.maximo != null)) {
      final minStr = m.minimo?.toStringAsFixed(2) ?? '';
      final maxStr = m.maximo?.toStringAsFixed(2) ?? '';
      final uni = (m.unidade ?? '').isNotEmpty ? ' ${m.unidade}' : '';
      if (minStr.isNotEmpty && maxStr.isNotEmpty) {
        subtitulo = '$minStr – $maxStr$uni';
      } else if (minStr.isNotEmpty) {
        subtitulo = '≥ $minStr$uni';
      } else if (maxStr.isNotEmpty) {
        subtitulo = '≤ $maxStr$uni';
      }
    }

    final vNum = _toDouble(_ctrl.text);
    final st = _classifica(vNum, m.minimo, m.maximo);

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(st),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.titulo.isEmpty ? '(sem título)' : m.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitulo, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: InputDecoration(
                labelText: 'Medição (${m.unidade ?? ''})',
                border: const OutlineInputBorder(),
                helperText: st == StatusMedida.ok
                    ? 'Dentro da tolerância'
                    : st == StatusMedida.pendente
                    ? 'Preencha o valor para classificar'
                    : (st == StatusMedida.reprovadaAbaixo
                          ? 'Abaixo do mínimo'
                          : 'Acima do máximo'),
                helperStyle: TextStyle(color: _statusColor(st)),
              ),
              onChanged: (txt) {
                final v = _toDouble(txt);
                final novoStatus = _classifica(v, m.minimo, m.maximo);
                widget.onChanged(novoStatus, txt);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
