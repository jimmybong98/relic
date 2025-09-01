import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/controllers/machine_controller.dart';
import 'package:admin/features/cadastro_maquinas/presentation/cadastro_maquinas_page.dart';
import 'package:admin/services/machine_service.dart';
import 'package:admin/models/machine.dart';

class _FakeMachineService implements MachineService {
  _FakeMachineService(this._items);

  final List<Machine> _items;
  final List<Machine> added = [];

  @override
  Future<List<Machine>> fetchMaquinas() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return List<Machine>.from(_items);
  }

  @override
  Future<bool> addMaquina(String codigo, String categoria) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final m = Machine(codigo: codigo, categoria: categoria);
    added.add(m);
    _items.add(m);
    return true;
  }
}

void main() {
  testWidgets('loads initial list and adds new machine', (tester) async {
    final service = _FakeMachineService([
      Machine(codigo: 'MX1', categoria: 'CAT1'),
    ]);
    final controller = MachineController(service: service);

    await tester.pumpWidget(MaterialApp(
      home: CadastroMaquinasPage(controller: controller),
    ));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('MX1 (CAT1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'CAT2');
    await tester.enterText(find.byType(TextField).at(1), 'MX2');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('MX2 (CAT2)'), findsOneWidget);
    expect(service.added.single.codigo, 'MX2');
    expect(service.added.single.categoria, 'CAT2');
  });
}
