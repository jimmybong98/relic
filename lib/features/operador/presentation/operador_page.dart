// lib/features/operador/presentation/operador_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../preparacao/data/models.dart';
import '../data/repository_provider.dart';
import 'package:admin/features/finalizar_os/presentation/finalizar_os_page.dart';
import 'package:admin/features/operador/presentation/troca_ferramenta_page.dart';
import 'package:admin/features/operador/presentation/widgets/measurement_tile.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/utils/api_base_url.dart';
import 'package:admin/widgets/search_summary_card.dart';
import 'package:admin/widgets/window_bar.dart';
import 'package:admin/utils/string_utils.dart';
import 'package:admin/services/machine_service.dart';
import 'package:admin/models/machine.dart';
import 'package:admin/features/shared/providers/search_flow_form_provider.dart';

final medidasOperadorControllerProvider =
StateNotifierProvider.autoDispose<
    MedidasOperadorController,
    AsyncValue<List<MedidaItem>>
>((ref) {
  return MedidasOperadorController(ref);
});

class MedidasOperadorController
    extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasOperadorController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String os,
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(operadorRepositoryProvider);
      final itens = await repo.getMedidas(
        os: os,
        partnumber: partnumber,
        operacao: operacao,
      );
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
      tolerancias: old.tolerancias,
      contagens: old.contagens,
      anguloMinimo: old.anguloMinimo,
      anguloMaximo: old.anguloMaximo,
    );
    state = AsyncValue.data(current);
  }

  /// Reseta todas as seleções (status -> pendente, medição -> null)
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
        tolerancias: old.tolerancias,
        contagens: old.contagens,
        anguloMinimo: old.anguloMinimo,
        anguloMaximo: old.anguloMaximo,
      );
    }
    state = AsyncValue.data(current);
  }

  /// Após um registro bem-sucedido, incrementa as contagens com base nas
  /// medições selecionadas e reseta os campos para nova entrada.
  void aplicarSelecoesComoHistorico() {
    final current = [...(state.value ?? const <MedidaItem>[])];
    for (var i = 0; i < current.length; i++) {
      final old = current[i];
      final counts = Map<String, int>.from(old.contagens);
      final raw = old.medicao ?? '';
      final partes = raw
          .split('|')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (partes.isEmpty) {
        // Para medições numéricas simples, `medicao` já é o valor escolhido.
        final label = raw.trim();
        if (label.isNotEmpty) {
          counts[label] = (counts[label] ?? 0) + 1;
        }
      } else {
        for (final parte in partes) {
          counts[parte] = (counts[parte] ?? 0) + 1;
        }
      }

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
        tolerancias: old.tolerancias,
        contagens: counts,
        anguloMinimo: old.anguloMinimo,
        anguloMaximo: old.anguloMaximo,
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
  bool _mostrarResumo = false;

  late final VoidCallback _osSyncListener;
  late final VoidCallback _partSyncListener;
  late final VoidCallback _opSyncListener;
  Timer? _amostragemMonitorTimer;
  SharedSearchFormState? _activeAmostragemFlow;
  bool _amostragemCheckInProgress = false;
  bool _amostragemReminderDialogOpen = false;
  DateTime? _lastAmostragem;
  DateTime? _lastReminderShownAt;

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

    _osCtrl.addListener(_osSyncListener);
    _partCtrl.addListener(_partSyncListener);
    _opCtrl.addListener(_opSyncListener);
    _carregarMaquinas();

    _handleFlowStateChange(null, shared);
  }

  void _handleFlowStateChange(
      SharedSearchFormState? previous,
      SharedSearchFormState next,
      ) {
    if (!next.isActive ||
        next.effectiveProcess != SearchFlowProcess.amostragem) {
      _activeAmostragemFlow = null;
      _cancelAmostragemMonitor();
      return;
    }

    final wasActive =
        previous != null &&
            previous.isActive &&
            previous.effectiveProcess == SearchFlowProcess.amostragem;

    final previousFlow = _activeAmostragemFlow;
    _activeAmostragemFlow = next;
    if (!wasActive || previousFlow == null || !next.matches(previousFlow)) {
      _resetAmostragemReminderState();
    }
    _ensureAmostragemMonitorRunning();
  }

  void _resetAmostragemReminderState() {
    _lastAmostragem = null;
    _lastReminderShownAt = null;
  }

  void _ensureAmostragemMonitorRunning() {
    if (_amostragemMonitorTimer != null) {
      return;
    }
    unawaited(_checkAmostragemRecente());
    _amostragemMonitorTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => unawaited(_checkAmostragemRecente()),
    );
  }

  void _cancelAmostragemMonitor() {
    _amostragemMonitorTimer?.cancel();
    _amostragemMonitorTimer = null;
    _amostragemCheckInProgress = false;
  }

  Future<void> _checkAmostragemRecente() async {
    if (_amostragemCheckInProgress) return;
    final flow = _activeAmostragemFlow;
    if (flow == null ||
        !flow.isActive ||
        flow.effectiveProcess != SearchFlowProcess.amostragem) {
      return;
    }

    final os = flow.os.trim();
    if (os.isEmpty) return;

    final part = flow.partNumber.trim();
    final op = flow.operacao.trim();
    final query = <String, dynamic>{
      'os': os,
      if (part.isNotEmpty) 'partnumber': part,
      if (op.isNotEmpty) 'operacao': op,
    };

    _amostragemCheckInProgress = true;
    try {
      final uri = buildApiUri('/operador/amostragens', query);
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        DateTime? ultimaAmostragem;
        try {
          final data = jsonDecode(resp.body);
          if (data is List && data.isNotEmpty) {
            final first = data.first;
            if (first is Map && first['created_at'] != null) {
              final raw = first['created_at'].toString();
              ultimaAmostragem = DateTime.tryParse(raw)?.toLocal();
              if (ultimaAmostragem == null) {
                ultimaAmostragem = DateTime.tryParse(
                  raw.replaceFirst(' ', 'T'),
                )?.toLocal();
              }
            }
          }
        } catch (_) {}
        _handleAmostragemRecente(flow, ultimaAmostragem);
      }
    } catch (_) {
      // Ignora falhas momentâneas; nova checagem ocorrerá em seguida.
    } finally {
      _amostragemCheckInProgress = false;
    }
  }

  void _handleAmostragemRecente(
      SharedSearchFormState flow,
      DateTime? ultimaAmostragem,
      ) {
    if (!mounted) return;
    if (ultimaAmostragem != null) {
      _lastAmostragem = ultimaAmostragem;
    }

    final now = DateTime.now();
    final last = _lastAmostragem;
    final reminderInterval = _resolveAmostragemReminderInterval(flow);
    final bool precisaAlertar;
    if (last == null) {
      precisaAlertar = true;
    } else {
      final diff = now.difference(last);
      precisaAlertar = diff >= reminderInterval;
      if (!precisaAlertar) {
        _lastReminderShownAt = null;
      }
    }

    if (precisaAlertar && _shouldShowAmostragemReminder(now)) {
      _showAmostragemReminder(flow, reminderInterval);
    }
  }

  bool _shouldShowAmostragemReminder(DateTime now) {
    if (_amostragemReminderDialogOpen) return false;
    final lastReminder = _lastReminderShownAt;
    if (lastReminder == null) return true;
    return now.difference(lastReminder) >= const Duration(minutes: 5);
  }

  Duration _resolveAmostragemReminderInterval(SharedSearchFormState flow) {
    final categoria = flow.categoria?.toLowerCase().trim();
    if (categoria == 'cnc alimentador') {
      return const Duration(minutes: 20);
    }
    if (categoria == 'centro de usinagem') {
      return const Duration(minutes: 15);
    }
    if (categoria == 'tornos com placa') {
      return const Duration(minutes: 40);
    }
    return const Duration(hours: 2);
  }

  String _formatReminderDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      final suffix = hours == 1 ? 'hora' : 'horas';
      return '$hours $suffix';
    }
    final suffix = minutes == 1 ? 'minuto' : 'minutos';
    return '$minutes $suffix';
  }

  Future<void> _showAmostragemReminder(
      SharedSearchFormState flow,
      Duration reminderInterval,
      ) async {
    if (!mounted || _amostragemReminderDialogOpen) return;
    _amostragemReminderDialogOpen = true;
    _lastReminderShownAt = DateTime.now();
    final os = flow.os.trim();
    final intervaloFormatado = _formatReminderDuration(reminderInterval);
    final mensagemBase =
        'Nenhuma amostragem foi registrada nos últimos $intervaloFormatado.';
    final mensagem = os.isEmpty
        ? mensagemBase
        : '$mensagemBase\nO.S. atual: $os';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção'),
        content: Text(mensagem),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    _amostragemReminderDialogOpen = false;
  }

  void _registrarAmostragemLocal() {
    _lastAmostragem = DateTime.now();
    _lastReminderShownAt = null;
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

  bool _maquinaSelecionadaValida() {
    final categoria = _categoriaSel;
    final maquina = _maquinaSel;
    if (categoria == null || maquina == null) return false;
    return _maquinas.any(
          (m) => m.categoria == categoria && m.codigo == maquina,
    );
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

  @override
  void dispose() {
    _cancelAmostragemMonitor();
    _osCtrl.removeListener(_osSyncListener);
    _partCtrl.removeListener(_partSyncListener);
    _opCtrl.removeListener(_opSyncListener);
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
        !_maquinaSelecionadaValida()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha RE, O.S. e máquina para registrar.'),
        ),
      );
      return;
    }

    if (!_ensureFlowConsistency()) return;

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
          content: Text('Faltam ${faltando.length} medições para selecionar.'),
        ),
      );
      return;
    }

    // Monta itens no formato que o backend espera
    final itens = <Map<String, dynamic>>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      final map = m.toMap();
      // índice esperado pelo backend
      map['indice'] = m.indice ?? map['indice'] ?? i;
      // backend espera 'min'/'max' e não 'minimo'/'maximo'
      map['min'] = m.minimo;
      map['max'] = m.maximo;
      // escolha = texto selecionado (OK / Aprovado / Reprovado / pílula etc.)
      map['escolha'] = m.medicao ?? '';

      // status como string; tampão envia "LP Aprovado | LNP Reprovado" com ambos os lados

      String status;
      final med = m.medicao ?? '';
      if (med.contains('Lado passa') && med.contains('Lado não passa')) {
        // Tampão: avalia cada lado separadamente
        var passa = 'LP Aprovado';
        var naoPassa = 'LNP Aprovado';
        for (final part in med.split('|')) {
          final p = part.trim();
          if (p.startsWith('Lado passa') && p.endsWith('Reprovado')) {
            passa = 'LP Reprovado';
          }
          if (p.startsWith('Lado não passa') && p.endsWith('Reprovado')) {
            naoPassa = 'LNP Reprovado';
          }
        }
        status = '$passa | $naoPassa';
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

    final uri = buildApiUri('/operador/registrar');

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
        ref
            .read(medidasOperadorControllerProvider.notifier)
            .aplicarSelecoesComoHistorico();
        _registrarAmostragemLocal();
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

  Future<bool> _fimJornada(String motivo) async {
    if (_reCtrl.text.trim().isEmpty || _osCtrl.text.trim().isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha RE e O.S. para finalizar.')),
      );
      return false;
    }

    if (!_ensureFlowConsistency()) return false;

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': normalizeCode(_partCtrl.text),
      'operacao': normalizeCode(_opCtrl.text),
      'motivo': motivo, // Adiciona o motivo selecionado
    });

    final uri = buildApiUri('/operador/fim_jornada');
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return false;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jornada pausada. Motivo: $motivo')),
        );
        if (motivo == 'Fim do Turno') {
          setState(() {
            _reCtrl.clear();
          });
        }
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    return false;
  }

  Future<void> _trocarOs() async {
    if (_reCtrl.text.trim().isEmpty || _osCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha RE e O.S. para trocar.')),
      );
      return;
    }

    if (!_ensureFlowConsistency()) return;

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': normalizeCode(_partCtrl.text),
      'operacao': normalizeCode(_opCtrl.text),
      'motivo': 'Troca de OS',
    });

    final uri = buildApiUri('/operador/troca_os');
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ref.read(sharedSearchFormProvider.notifier).clear();
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O.S. pausada para troca. Solicite nova liberação antes de retomar.',
            ),
          ),
        );
      } else {
        String mensagem = 'Falha: ${resp.statusCode} ${resp.body}';
        try {
          final data = jsonDecode(resp.body);
          if (data is Map && data['error'] is String) {
            final texto = (data['error'] as String).trim();
            if (texto.isNotEmpty) mensagem = texto;
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _iniciarTrocaFerramenta() async {
    final re = _reCtrl.text.trim();
    final os = _osCtrl.text.trim();
    final part = _partCtrl.text.trim();
    final operacao = _opCtrl.text.trim();
    final maquinaValida = _maquinaSelecionadaValida();
    final maquina = maquinaValida ? (_maquinaSel ?? '').trim() : '';

    if (re.isEmpty ||
        os.isEmpty ||
        part.isEmpty ||
        operacao.isEmpty ||
        !maquinaValida) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha R.E., O.S., peça, operação e máquina antes de trocar a ferramenta.',
          ),
        ),
      );
      return;
    }

    final sucesso = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrocaFerramentaPage(
          re: re,
          os: os,
          partnumber: part,
          operacao: operacao,
          maquina: maquina,
        ),
      ),
    );

    if (sucesso == true) {
      await _fimJornada('Troca de ferramenta');
    }
  }

  Future<void> _showFimJornadaDialog() async {
    const motivos = <String>[
      'Banheiro',
      'Refeição',
      'Fim do Turno',
      'Manutenção',
      'Falta de Material',
      'Problema de Qualidade',
      'Outros',
    ];

    final motivo = await showDialog<String>(
      context: context,
      builder: (context) {
        String? selecionado;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Pausa de Jornada'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: motivos
                    .map(
                      (m) => RadioListTile<String>(
                    title: Text(m),
                    value: m,
                    groupValue: selecionado,
                    onChanged: (value) =>
                        setState(() => selecionado = value),
                  ),
                )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selecionado == null
                    ? null
                    : () => Navigator.of(context).pop(selecionado),
                child: const Text('Avançar'),
              ),
            ],
          ),
        );
      },
    );

    if (motivo == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar motivo'),
        content: Text('Deseja confirmar a opção "$motivo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    await _fimJornada(motivo);
  }

  Future<void> _encerrarProducao() async {
    if (_osCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a O.S. para encerrar.')),
      );
      return;
    }

    if (!_ensureFlowConsistency()) return;

    final body = jsonEncode({'os': _osCtrl.text.trim()});
    final uri = buildApiUri('/operador/encerrar_producao');
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produção encerrada.')));
        await _abrirPaginaFinalizacaoOs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
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

  Future<void> _confirmTrocaOs() async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Troca de O.S.'),
        content: const Text(
          'Deseja pausar a O.S. atual e liberar o fluxo para iniciar outra? '
              'Será necessária nova liberação para retomar a produção desta O.S.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirma == true) {
      await _trocarOs();
    }
  }

  Future<void> _abrirPaginaFinalizacaoOs() async {
    if (!_ensureFlowConsistency()) return;

    final notifier = ref.read(sharedSearchFormProvider.notifier);
    final iniciouFluxo = notifier.beginFlow(
      os: _osCtrl.text,
      partNumber: _partCtrl.text,
      operacao: _opCtrl.text,
      categoria: _categoriaSel,
      maquina: _maquinaSel,
      process: SearchFlowProcess.finalizacao,
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
    ).push(MaterialPageRoute(builder: (_) => const FinalizarOsPage()));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SharedSearchFormState>(sharedSearchFormProvider, (
        previous,
        next,
        ) {
      _handleFlowStateChange(previous, next);
    });

    final medidasAsync = ref.watch(medidasOperadorControllerProvider);
    final medidas = medidasAsync.value ?? [];
    final flowState = ref.watch(sharedSearchFormProvider);
    final flowLocked = flowState.isActive;
    final flowProcessName = flowState.processDisplayName;
    final flowOs = flowState.os.trim();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final actionBottomPadding = bottomInset > 0 ? bottomInset + 16.0 : 16.0;
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

    // todas respondidas?
    final todasRespondidas =
        medidas.isNotEmpty &&
            medidas.every(
                  (m) =>
              m.status != StatusMedida.pendente && (m.medicao ?? '').isNotEmpty,
            );

    final podeRegistrar =
        formMatchesFlow &&
            reOk &&
            osOk &&
            maquinaOk &&
            todasRespondidas &&
            !_registrando;

    return Scaffold(
      appBar: WindowBar(
        title: 'Amostragem - FOR009-14',
        titleSvgAsset: 'assets/icons/farol.svg',
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
      drawer: const SideMenu(current: SideMenuSection.operador),
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
                      SearchSummarySection(
                        reLabel: 'R.E. do Preparador',
                        reValue: _reCtrl.text,
                        items: [
                          SummaryInfo(label: 'O.S.', value: _osCtrl.text),
                          SummaryInfo(label: 'Peça', value: _partCtrl.text),
                          SummaryInfo(label: 'Operação', value: _opCtrl.text),
                          if ((maquinaValue ?? '').isNotEmpty)
                            SummaryInfo(label: 'Máquina', value: maquinaValue!),
                          if ((categoriaValue ?? '').isNotEmpty)
                            SummaryInfo(
                              label: 'Categoria',
                              value: categoriaValue!,
                            ),
                        ],
                        onEdit: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _mostrarResumo = false);
                        },
                      ),
                    ] else ...[
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
                                      if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                        return 'Apenas números';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 140, // igual ao campo Operação
                                  child: TextFormField(
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
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Obrigatório';
                                      if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                        return 'Apenas números';
                                      }
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
                                    value: categoriaValue,
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
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
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
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _partCtrl,
                                    enabled: !flowLocked,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Código da peça (PartNumber)',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Obrigatório'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 140,
                                  child: TextFormField(
                                    controller: _opCtrl,
                                    enabled: !flowLocked,
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
                                      if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                        return 'Apenas números';
                                      }
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
                                    if (!_ensureFlowConsistency()) return;
                                    FocusScope.of(context).unfocus();
                                    await ref
                                        .read(
                                      medidasOperadorControllerProvider
                                          .notifier,
                                    )
                                        .carregar(
                                      os: _osCtrl.text.trim(),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'ferramenta') {
                                _iniciarTrocaFerramenta();
                              } else if (value == 'fim') {
                                _showFimJornadaDialog();
                              } else if (value == 'troca') {
                                _confirmTrocaOs();
                              } else if (value == 'encerrar') {
                                _confirmEncerrarProducao();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'ferramenta',
                                child: Text('Troca de ferramenta'),
                              ),
                              PopupMenuItem(
                                value: 'fim',
                                child: Text('Pausa de Jornada'),
                              ),
                              PopupMenuItem(
                                value: 'troca',
                                child: Text('Troca de O.S.'),
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
                            onPressed: podeRegistrar
                                ? _registrarAmostragem
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
                            label: const Text('Registrar amostragem'),
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
                  onSelect: (status, medicao) => ref
                      .read(medidasOperadorControllerProvider.notifier)
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