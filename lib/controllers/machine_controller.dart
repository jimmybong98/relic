import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controller that stores the list of available machine codes.
class MachineListController extends StateNotifier<List<String>> {
  MachineListController() : super(const []);

  /// Adds a new machine code if it is not empty and not already present.
  void add(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    if (state.contains(trimmed)) return;
    state = [...state, trimmed];
  }
}

/// Provider exposing the list of machine codes to the application.
final machineListProvider =
    StateNotifierProvider<MachineListController, List<String>>(
        (ref) => MachineListController());
