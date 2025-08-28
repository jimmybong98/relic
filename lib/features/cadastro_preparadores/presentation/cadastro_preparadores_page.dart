import 'package:flutter/material.dart';
import 'package:admin/screens/main/components/side_menu.dart';

class CadastroPreparadoresPage extends StatelessWidget {
  const CadastroPreparadoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Preparadores')),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: const Center(child: Text('Cadastro de Preparadores')),
    );
  }
}
