import 'package:flutter/material.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';

class CadastroPreparadoresPage extends StatelessWidget {
  const CadastroPreparadoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WindowBar(title: 'Cadastro de Preparadores'),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: const Center(child: Text('Cadastro de Preparadores')),
    );
  }
}
