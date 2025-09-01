import 'package:flutter/foundation.dart';

import '../services/machine_service.dart';
import '../models/machine.dart';

class MachineController extends ChangeNotifier {
  MachineController({MachineService? service})
      : _service = service ?? MachineService();

  final MachineService _service;

  final List<Machine> maquinas = [];
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  Future<void> fetchMaquinas() async {
    try {
      isLoading = true;
      notifyListeners();
      final data = await _service.fetchMaquinas();
      maquinas
        ..clear()
        ..addAll(data);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMaquina(String codigo, String categoria) async {
    try {
      isSaving = true;
      notifyListeners();
      final ok = await _service.addMaquina(codigo, categoria);
      if (ok) {
        maquinas.add(Machine(codigo: codigo, categoria: categoria));
        error = null;
      } else {
        error = 'Falha ao adicionar';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
