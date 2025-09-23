import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const sharedSearchFlowBoxName = 'shared_search_flow';
const _sharedSearchFlowStateKey = 'state';

enum SearchFlowProcess { amostragem, finalizacao }

extension SearchFlowProcessDisplay on SearchFlowProcess {
  String get displayName {
    switch (this) {
      case SearchFlowProcess.amostragem:
        return 'Amostragem';
      case SearchFlowProcess.finalizacao:
        return 'Finalização de O.S.';
    }
  }
}

SearchFlowProcess? _parseProcess(dynamic raw) {
  if (raw is! String) return null;
  for (final process in SearchFlowProcess.values) {
    if (process.name == raw) {
      return process;
    }
  }
  return null;
}

class SharedSearchFormState {
  const SharedSearchFormState({
    this.isActive = false,
    this.os = '',
    this.partNumber = '',
    this.operacao = '',
    this.categoria,
    this.maquina,
    this.process,
  });

  final bool isActive;
  final String os;
  final String partNumber;
  final String operacao;
  final String? categoria;
  final String? maquina;
  final SearchFlowProcess? process;

  static const _sentinel = Object();
  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
  factory SharedSearchFormState.fromMap(Map<dynamic, dynamic> map) {
    String _readString(dynamic value) => (value ?? '').toString().trim();
    String? _readOptional(dynamic value) {
      if (value == null) return null;
      return _normalizeOptional(value.toString());
    }

    return SharedSearchFormState(
      isActive: map['isActive'] == true,
      os: _readString(map['os']),
      partNumber: _readString(map['partNumber']),
      operacao: _readString(map['operacao']),
      categoria: _readOptional(map['categoria']),
      maquina: _readOptional(map['maquina']),
      process: _parseProcess(map['process']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'os': os,
      'partNumber': partNumber,
      'operacao': operacao,
      'categoria': categoria,
      'maquina': maquina,
      'process': process?.name,
    };
  }

  SharedSearchFormState copyWith({
    bool? isActive,
    String? os,
    String? partNumber,
    String? operacao,
    Object? categoria = _sentinel,
    Object? maquina = _sentinel,
    Object? process = _sentinel,
  }) {
    return SharedSearchFormState(
      isActive: isActive ?? this.isActive,
      os: os ?? this.os,
      partNumber: partNumber ?? this.partNumber,
      operacao: operacao ?? this.operacao,
      categoria: categoria == _sentinel ? this.categoria : categoria as String?,
      maquina: maquina == _sentinel ? this.maquina : maquina as String?,
      process: process == _sentinel
          ? this.process
          : process as SearchFlowProcess?,
    );
  }

  bool matches(SharedSearchFormState other) {
    return os == other.os &&
        partNumber == other.partNumber &&
        operacao == other.operacao &&
        categoria == other.categoria &&
        maquina == other.maquina;
  }

  bool equals(SharedSearchFormState other) {
    return isActive == other.isActive &&
        matches(other) &&
        process == other.process;
  }

  bool matchesValues({
    required String os,
    required String partNumber,
    required String operacao,
    String? categoria,
    String? maquina,
  }) {
    return matches(
      SharedSearchFormState(
        isActive: true,
        os: os.trim(),
        partNumber: partNumber.trim(),
        operacao: operacao.trim(),
        categoria: _normalizeOptional(categoria),
        maquina: _normalizeOptional(maquina),
      ),
    );
  }
}

extension SharedSearchFormStateDisplay on SharedSearchFormState {
  SearchFlowProcess get effectiveProcess =>
      process ?? SearchFlowProcess.amostragem;

  String get processDisplayName => effectiveProcess.displayName;
}

SharedSearchFormState _restoreInitialState(Box<Map> box) {
  if (!box.isOpen) return const SharedSearchFormState();
  final raw = box.get(_sharedSearchFlowStateKey);
  if (raw is Map) {
    try {
      return SharedSearchFormState.fromMap(raw);
    } catch (_) {
      return const SharedSearchFormState();
    }
  }
  return const SharedSearchFormState();
}

class SharedSearchFormController extends StateNotifier<SharedSearchFormState> {
  SharedSearchFormController(this._box) : super(_restoreInitialState(_box));

  final Box<Map> _box;

  bool get _isActive => state.isActive;

  void _persist(SharedSearchFormState value) {
    if (!_box.isOpen) return;
    if (!value.isActive) {
      if (_box.containsKey(_sharedSearchFlowStateKey)) {
        _box.delete(_sharedSearchFlowStateKey);
      }
      return;
    }

    _box.put(_sharedSearchFlowStateKey, value.toMap());
  }

  void _updateState(SharedSearchFormState newState) {
    if (state.equals(newState)) {
      return;
    }
    state = newState;
    _persist(newState);
  }

  bool beginFlow({
    required String os,
    required String partNumber,
    required String operacao,
    String? categoria,
    String? maquina,
    SearchFlowProcess process = SearchFlowProcess.amostragem,
  }) {
    final candidate = SharedSearchFormState(
      isActive: true,
      os: os.trim(),
      partNumber: partNumber.trim(),
      operacao: operacao.trim(),
      categoria: SharedSearchFormState._normalizeOptional(categoria),
      maquina: SharedSearchFormState._normalizeOptional(maquina),
      process: process,
    );

    if (_isActive && state.matches(candidate) == false) {
      return false;
    }
    _updateState(candidate);
    return true;
  }

  void setOs(String value) {
    if (_isActive == false) return;
    final trimmed = value.trim();
    if (trimmed == state.os) return;
    _updateState(state.copyWith(os: trimmed));
  }

  void setPartNumber(String value) {
    if (_isActive == false) return;
    final trimmed = value.trim();
    if (trimmed == state.partNumber) return;
    _updateState(state.copyWith(partNumber: trimmed));
  }

  void setOperacao(String value) {
    if (_isActive == false) return;
    final trimmed = value.trim();
    if (trimmed == state.operacao) return;
    _updateState(state.copyWith(operacao: trimmed));
  }

  void setCategoria(String? categoria) {
    if (_isActive == false) return;

    if (categoria == state.categoria) return;
    _updateState(
      state.copyWith(
        categoria: categoria,
        maquina: categoria == state.categoria ? state.maquina : null,
      ),
    );
  }

  void setMaquina(String? maquina) {
    if (_isActive == false) return;
    if (maquina == state.maquina) return;
    _updateState(state.copyWith(maquina: maquina));
  }

  void clear() {
    if (!state.isActive && state.os.isEmpty && state.partNumber.isEmpty) {
      if (_box.isOpen && _box.containsKey(_sharedSearchFlowStateKey)) {
        _box.delete(_sharedSearchFlowStateKey);
      }
      state = const SharedSearchFormState();
      return;
    }
    _updateState(const SharedSearchFormState());
  }
}

SharedSearchFormController _createSharedSearchFormController(Ref ref) {
  final box = Hive.box<Map>(sharedSearchFlowBoxName);
  return SharedSearchFormController(box);
}

final sharedSearchFormProvider =
    StateNotifierProvider<SharedSearchFormController, SharedSearchFormState>(
      _createSharedSearchFormController,
    );
