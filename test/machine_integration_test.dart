import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/controllers/machine_controller.dart';
import 'package:admin/features/cadastro_maquinas/presentation/cadastro_maquinas_page.dart';
import 'package:admin/services/machine_service.dart';

class _FakeMachineService implements MachineService {
  _FakeMachineService(this._items);

  final List<String> _items;
  final List<String> added = [];

  @override
  Future<List<String>> fetchMaquinas() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return List<String>.from(_items);
  }

  @override
  Future<bool> addMaquina(String codigo) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    added.add(codigo);
    _items.add(codigo);
    return true;
  }
}

void main() {
  testWidgets('loads initial list and adds new machine', (tester) async {
    final service = _FakeMachineService(['MX1']);
    final controller = MachineController(service: service);

    await tester.pumpWidget(MaterialApp(
      home: CadastroMaquinasPage(controller: controller),
    ));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('MX1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'MX2');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('MX2'), findsOneWidget);
    expect(service.added, ['MX2']);
  });
}
