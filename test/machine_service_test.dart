import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:admin/services/machine_service.dart';

void main() {
  test('parses list responses', () async {
    final client =
        MockClient((req) async => http.Response('[["C1","M1"]]', 200));
    final service = MachineService(client: client, baseUrl: 'http://dummy');
    final machines = await service.fetchMaquinas();
    expect(machines.single.codigo, 'M1');
    expect(machines.single.categoria, 'C1');
  });

  test('parses wrapped map responses', () async {
    final client = MockClient((req) async => http.Response('{"machines":[{"codigo":"M2","categoria":"C2"}]}', 200));
    final service = MachineService(client: client, baseUrl: 'http://dummy');
    final machines = await service.fetchMaquinas();
    expect(machines.single.codigo, 'M2');
    expect(machines.single.categoria, 'C2');
  });
}
