// lib/features/operador/presentation/operador_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../preparacao/data/models.dart';
import '../data/repository_provider.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/utils/string_utils.dart';
import 'package:admin/services/machine_service.dart';
import 'package:admin/models/machine.dart';

/// >>>>> Ajuste para o endereço/porta do seu Flask <<<<<
const String kBaseUrl = 'http://192.168.0.241:5005';

final medidasOperadorControllerProvider = StateNotifierProvider.autoDispose<
    MedidasOperadorController, AsyncValue<List<MedidaItem>>>((ref) {
  return MedidasOperadorController(ref);
});

class MedidasOperadorController
    extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasOperadorController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(operadorRepositoryProvider);
      final itens =
      await repo.getMedidas(partnumber: partnumber, operacao: operacao);
      state = AsyncValue.data(itens);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Define status e medição (texto) para um índice.
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

  /// Reseta todas as seleções (status -> pendente, medição -> null)
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

class OperadorPage extends ConsumerStatefulWidget {
  const OperadorPage({super.key});

  @override
  ConsumerState<OperadorPage> createState() => _OperadorPageState();
}

class _OperadorPageState extends ConsumerState<OperadorPage> {
  final _formKey = GlobalKey<FormState>();
  final _reCtrl = TextEditingController();
  final _osCtrl = TextEditingController(); // <<<< O.S.
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();

  final List<Machine> _maquinas = [];
  final List<String> _categorias = [];
  String? _categoriaSel;
  String? _maquinaSel;

  bool _registrando = false;

  @override
  void initState() {
    super.initState();
    _carregarMaquinas();
  }

  Future<void> _carregarMaquinas() async {
    try {
      final list = await MachineService().fetchMaquinas();
      if (mounted) {
        setState(() {
          _maquinas.addAll(list);
          _categorias.addAll(
              _maquinas.map((e) => e.categoria).toSet().toList()..sort());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao carregar máquinas: $e')));
      }
    }
  }

  @override
  void dispose() {
    _reCtrl.dispose();
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarAmostragem() async {
    final medidas = ref.read(medidasOperadorControllerProvider).value ?? [];

    // Valida RE/OS/Máquina
    if (_reCtrl.text.trim().isEmpty ||
        _osCtrl.text.trim().isEmpty ||
        (_maquinaSel ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha RE, O.S. e máquina para registrar.')),
      );
      return;
    }

    // Todas respondidas?
    final faltando = <int>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      if (m.status == StatusMedida.pendente ||
          (m.medicao == null || m.medicao!.isEmpty)) {
        faltando.add(i);
      }
    }
    if (faltando.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Faltam ${faltando.length} medições para selecionar.')),
      );
      return;
    }

    // Monta itens no formato que o backend espera
    final itens = <Map<String, dynamic>>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      final map = m.toMap();
      // índice esperado pelo backend
      map['indice'] = i;
      // backend espera 'min'/'max' e não 'minimo'/'maximo'
      map['min'] = m.minimo;
      map['max'] = m.maximo;
      // escolha = texto selecionado (OK / Aprovado / Reprovado / pílula etc.)
      map['escolha'] = m.medicao ?? '';

      // status como string; tampão envia "aprovado|reprovado" com ambos os lados

      String status;
      final med = m.medicao ?? '';
      if (med.contains('Lado passa') && med.contains('Lado não passa')) {
        // Tampão: avalia cada lado separadamente
        var passa = 'aprovado';
        var naoPassa = 'aprovado';
        for (final part in med.split('|')) {
          final p = part.trim();
          if (p.startsWith('Lado passa') && p.endsWith('Reprovado')) {
            passa = 'reprovado';
          }
          if (p.startsWith('Lado não passa') && p.endsWith('Reprovado')) {
            naoPassa = 'reprovado';
          }
        }
        status = '$passa|$naoPassa';
      } else {
        status = statusToString(m.status);
      }
      map['status'] = status;
      itens.add(map);
    }

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': normalizeCode(_partCtrl.text),
      'operacao': normalizeCode(_opCtrl.text),
      'maquina': _maquinaSel,
      // >>> chave correta no backend:
      'itens': itens,
    });

    final uri = Uri.parse('$kBaseUrl/operador/registrar');

    setState(() => _registrando = true);
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amostragem registrada com sucesso!')),
        );
        // Limpa seleções, mantém lista
        ref.read(medidasOperadorControllerProvider.notifier).resetSelecoes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Falha ao registrar: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  Future<void> _fimJornada() async {
    if (_reCtrl.text.trim().isEmpty || _osCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha RE e O.S. para finalizar.')),
      );
      return;
    }

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': normalizeCode(_partCtrl.text),
      'operacao': normalizeCode(_opCtrl.text),
    });

    final uri = Uri.parse('$kBaseUrl/operador/fim_jornada');
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jornada pausada.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _encerrarProducao() async {
    if (_osCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a O.S. para encerrar.')),
      );
      return;
    }

    final body = jsonEncode({'os': _osCtrl.text.trim()});
    final uri = Uri.parse('$kBaseUrl/operador/encerrar_producao');
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produção encerrada.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _confirmEncerrarProducao() async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar produção'),
        content: const Text('Tem certeza que deseja encerrar a produção?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirma == true) {
      await _encerrarProducao();
    }
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasOperadorControllerProvider);
    final medidas = medidasAsync.value ?? [];
    final reOk = _reCtrl.text.trim().isNotEmpty;
    final osOk = _osCtrl.text.trim().isNotEmpty;
    final maquinaOk = (_maquinaSel ?? '').isNotEmpty;

    // todas respondidas?
    final todasRespondidas = medidas.isNotEmpty &&
        medidas.every((m) =>
        m.status != StatusMedida.pendente && (m.medicao ?? '').isNotEmpty);

    final podeRegistrar =
        reOk && osOk && maquinaOk && todasRespondidas && !_registrando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Operador'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                Platform.isWindows ? 'Windows: leitura direta/API' : 'Android: via API',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
        ],
      ),
      drawer: const SideMenu(current: SideMenuSection.operador),
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
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'R.E. do Preparador', // ajuste o texto se for Operador
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s)) return 'Apenas números';
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
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'O.S.',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s)) return 'Apenas números';
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
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
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
                                .map((m) => DropdownMenuItem(
                                    value: m.codigo, child: Text(m.codigo)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _maquinaSel = v),
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
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            controller: _opCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Operação',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Obrigatório';
                              if (!RegExp(r'^\d+$').hasMatch(s)) return 'Apenas números';
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
                                .read(medidasOperadorControllerProvider.notifier)
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
                        child: Text('Nenhuma medida encontrada para a chave informada.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _MeasurementTile(
                          index: index,
                          item: item,
                          onSelect: (status, medicao) => ref
                              .read(medidasOperadorControllerProvider.notifier)
                              .setStatusAndMedicao(index, status, medicao),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Erro ao carregar:\n${e.toString()}'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'fim') _fimJornada();
                    if (value == 'encerrar') _confirmEncerrarProducao();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'fim',
                      child: Text('Fim de Jornada'),
                    ),
                    PopupMenuItem(
                      value: 'encerrar',
                      child: Text('Encerrar produção'),
                    ),
                  ],
                ),

              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: podeRegistrar ? _registrarAmostragem : null,
                  icon: _registrando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Registrar amostragem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final int index;
  final MedidaItem item;
  final void Function(StatusMedida status, String? medicao) onSelect;

  const _MeasurementTile({
    required this.index,
    required this.item,
    required this.onSelect,
  });

  // ---------- helpers ----------
  String _norm(String? s) => (s ?? '').trim();
  String _nfd(String s) {
    // normalização simples (sem pacote intl)
    const rep = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a',
      'é': 'e', 'ê': 'e',
      'í': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u',
      'ç': 'c',
      'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A',
      'É': 'E', 'Ê': 'E',
      'Í': 'I',
      'Ó': 'O', 'Ô': 'O', 'Õ': 'O',
      'Ú': 'U',
      'Ç': 'C',
    };
    var t = s;
    rep.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  bool _containsAny(String hay, List<String> needles) {
    final h = _nfd(hay.toLowerCase());
    return needles.any((n) => h.contains(_nfd(n.toLowerCase())));
  }

  bool get _isVisualRugParalelismoOrAfins {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, ['visual', 'rug', 'paralelismo', 'anel de rosca passa', 'cqf', 'simetria', 'concentricidade']) ||
        _containsAny(inst, ['visual', 'rug', 'rugosimetro', 'paralelismo', 'anel de rosca passa', 'cqf', 'simetria']);
  }

  bool get _isTampao {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, ['tamp', 'tampao', 'tampão', 'tampa']) ||
        _containsAny(inst, ['tamp', 'tampao', 'tampão', 'tampa']);
  }

  Set<String> _partsFromMedicao(String? medicao) =>
      (medicao ?? '')
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();

  String _joinParts(Set<String> parts) => parts.join(' | ');

  StatusMedida _statusFromParts(Set<String> parts) {
    final hasPassa = parts.any((p) => p.startsWith('Lado passa'));
    final hasNaoPassa =
        parts.any((p) => p.startsWith('Lado não passa'));
    if (hasPassa && hasNaoPassa) {
      final passaReprovado = parts.contains('Lado passa — Reprovado');
      final naoPassaReprovado =
          parts.contains('Lado não passa — Reprovado');
      if (passaReprovado && naoPassaReprovado) {
        return StatusMedida.reprovadaAcima;
      }
      if (passaReprovado) return StatusMedida.reprovadaAbaixo;
      if (naoPassaReprovado) return StatusMedida.reprovadaAcima;
      return StatusMedida.ok;
    }
    return StatusMedida.pendente;
  }

  double? _toDoubleNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.').trim());
  }

  bool _near(double a, double b) => (a - b).abs() <= 0.005;

  Color _fgOn(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87;

  Widget _pill({
    required String text,
    required Color bg,
    required Color border,
    bool selected = false,
    Color? fg,
    VoidCallback? onTap,
  }) {
    final fgColor = fg ?? _fgOn(bg);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? border.withValues(alpha: 0.9) : border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styleLabel = Theme.of(context).textTheme.titleMedium;
    final styleSpec = Theme.of(context).textTheme.bodyMedium;

    String subtitulo = item.faixaTexto;
    if (subtitulo.isEmpty && (item.minimo != null || item.maximo != null)) {
      final minStr = item.minimo?.toStringAsFixed(2) ?? '';
      final maxStr = item.maximo?.toStringAsFixed(2) ?? '';
      final uni = (item.unidade ?? '').isNotEmpty ? ' ${item.unidade}' : '';
      if (minStr.isNotEmpty && maxStr.isNotEmpty) {
        subtitulo = '$minStr – $maxStr$uni';
      } else if (minStr.isNotEmpty) {
        subtitulo = '≥ $minStr$uni';
      } else if (maxStr.isNotEmpty) {
        subtitulo = '≤ $maxStr$uni';
      }
    }

    // NÃO usar ?? [] se tolerancias for não-nulo (evita dead_null_aware_expression)
    final tolerancias = item.tolerancias;

    // ------- UI -------
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.titulo.isEmpty ? '(sem título)' : item.titulo, style: styleLabel),
          if (subtitulo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitulo, style: styleSpec),
          ],
          if ((item.periodicidade ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Periodicidade: ${item.periodicidade}', style: styleSpec),
          ],
          if ((item.instrumento ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Instrumento: ${item.instrumento}', style: styleSpec),
          ],
          const SizedBox(height: 10),

          // Modo 1: Visual/Rug/Paralelismo/Anel de rosca passa/CQF/Simetria (binário)
          if (_isVisualRugParalelismoOrAfins) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  text: 'Aprovado',
                  bg: Colors.green.shade200,
                  border: Colors.green.shade600,
                  fg: Colors.green.shade900,
                  selected: item.medicao == 'Aprovado',
                  onTap: () => onSelect(StatusMedida.ok, 'Aprovado'),
                ),
                _pill(
                  text: 'Reprovado',
                  bg: Colors.red.shade100,
                  border: Colors.red.shade400,
                  selected: item.medicao == 'Reprovado',
                  onTap: () =>
                      onSelect(StatusMedida.reprovadaAcima, 'Reprovado'),
                ),
              ],
            ),
          ]
          // Modo 2: Tampão (4 botões)
          else if (_isTampao) ...[
            Builder(builder: (context) {
              final parts = _partsFromMedicao(item.medicao);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    text: 'Lado passa — Aprovado',
                    bg: Colors.green.shade200,
                    border: Colors.green.shade600,
                    fg: Colors.green.shade900,
                    selected: parts.contains('Lado passa — Aprovado'),
                    onTap: () {
                      final p = _partsFromMedicao(item.medicao);
                      p.removeWhere((e) => e.startsWith('Lado passa'));
                      p.add('Lado passa — Aprovado');
                      onSelect(_statusFromParts(p), _joinParts(p));
                    },
                  ),
                  _pill(
                    text: 'Lado passa — Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected: parts.contains('Lado passa — Reprovado'),
                    onTap: () {
                      final p = _partsFromMedicao(item.medicao);
                      p.removeWhere((e) => e.startsWith('Lado passa'));
                      p.add('Lado passa — Reprovado');
                      onSelect(_statusFromParts(p), _joinParts(p));
                    },
                  ),
                  _pill(
                    text: 'Lado não passa — Aprovado',
                    bg: Colors.green.shade200,
                    border: Colors.green.shade600,
                    fg: Colors.green.shade900,
                    selected: parts.contains('Lado não passa — Aprovado'),
                    onTap: () {
                      final p = _partsFromMedicao(item.medicao);
                      p.removeWhere((e) => e.startsWith('Lado não passa'));
                      p.add('Lado não passa — Aprovado');
                      onSelect(_statusFromParts(p), _joinParts(p));
                    },
                  ),
                  _pill(
                    text: 'Lado não passa — Reprovado',
                    bg: Colors.red.shade100,
                    border: Colors.red.shade400,
                    selected: parts.contains('Lado não passa — Reprovado'),
                    onTap: () {
                      final p = _partsFromMedicao(item.medicao);
                      p.removeWhere((e) => e.startsWith('Lado não passa'));
                      p.add('Lado não passa — Reprovado');
                      onSelect(_statusFromParts(p), _joinParts(p));
                    },
                  ),
                ],
              );
            }),
          ]
          // Modo 3: Pílulas de tolerância + OK
          else ...[
              Builder(
                builder: (context) {
                  final chips = <Widget>[];

                  // Monta as 4 pílulas coloridas na ordem recebida
                  for (var i = 0; i < tolerancias.length; i++) {
                    final raw = tolerancias[i];
                    final d = _toDoubleNum(raw);

                    // Define cores e status conforme a posição
                    StatusMedida st;
                    Color bg;
                    Color bd;
                    switch (i) {
                      case 0:
                        st = StatusMedida.reprovadaAbaixo;
                        bg = Colors.red.shade100;
                        bd = Colors.red.shade400;
                        break;
                      case 1:
                        st = StatusMedida.alertaAbaixo;
                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                        break;
                      case 2:
                        st = StatusMedida.alertaAcima;
                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                        break;
                      case 3:
                        st = StatusMedida.reprovadaAcima;
                        bg = Colors.red.shade100;
                        bd = Colors.red.shade400;
                        break;
                      default:

                        st = StatusMedida.alertaAbaixo;

                        bg = Colors.amber.shade100;
                        bd = Colors.amber.shade400;
                    }

                    final label =
                        d != null ? d.toStringAsFixed(2) : raw.toString();
                    final selected = item.medicao == label;

                    chips.add(_pill(
                      text: label,
                      bg: bg,
                      border: bd,
                      selected: selected,
                      onTap: () => onSelect(st, label),
                    ));
                  }

                  // Insere OK central
                  final mid = chips.isEmpty ? 0 : (chips.length ~/ 2);
                  chips.insert(
                    mid,
                    _pill(
                      text: 'OK',
                      bg: Colors.green.shade200,
                      border: Colors.green.shade600,
                      fg: Colors.green.shade900,
                      selected: item.medicao == 'OK',
                      onTap: () => onSelect(StatusMedida.ok, 'OK'),
                    ),
                  );

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  );
                },
              ),
            ],
        ]),
      ),
    );
  }
}
