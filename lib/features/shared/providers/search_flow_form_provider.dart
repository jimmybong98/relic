import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedSearchFormState {
  const SharedSearchFormState({
    this.os = '',
    this.partNumber = '',
    this.operacao = '',
    this.categoria,
    this.maquina,
  });

  final String os;
  final String partNumber;
  final String operacao;
  final String? categoria;
  final String? maquina;

  static const _sentinel = Object();

  SharedSearchFormState copyWith({
    String? os,
    String? partNumber,
    String? operacao,
    Object? categoria = _sentinel,
    Object? maquina = _sentinel,
  }) {
    return SharedSearchFormState(
      os: os ?? this.os,
      partNumber: partNumber ?? this.partNumber,
      operacao: operacao ?? this.operacao,
      categoria: categoria == _sentinel ? this.categoria : categoria as String?,
      maquina: maquina == _sentinel ? this.maquina : maquina as String?,
    );
  }
}

class SharedSearchFormController extends StateNotifier<SharedSearchFormState> {
  SharedSearchFormController() : super(const SharedSearchFormState());

  void setOs(String value) {
    final trimmed = value.trim();
    if (trimmed == state.os) return;
    state = state.copyWith(os: trimmed);
  }

  void setPartNumber(String value) {
    final trimmed = value.trim();
    if (trimmed == state.partNumber) return;
    state = state.copyWith(partNumber: trimmed);
  }

  void setOperacao(String value) {
    final trimmed = value.trim();
    if (trimmed == state.operacao) return;
    state = state.copyWith(operacao: trimmed);
  }

  void setCategoria(String? categoria) {
    if (categoria == state.categoria) return;
    state = state.copyWith(
      categoria: categoria,
      maquina: categoria == state.categoria ? state.maquina : null,
    );
  }

  void setMaquina(String? maquina) {
    if (maquina == state.maquina) return;
    state = state.copyWith(maquina: maquina);
  }

  void clear() {
    state = const SharedSearchFormState();
  }
}

final sharedSearchFormProvider =
    StateNotifierProvider<SharedSearchFormController, SharedSearchFormState>(
      (ref) => SharedSearchFormController(),
    );
