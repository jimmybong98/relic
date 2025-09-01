import 'package:flutter/material.dart';

import 'package:admin/screens/main/main_screen.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';
import '../finalizar_os/presentation/finalizar_os_page.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    void open(BuildContext context, Widget page) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Menu Principal')),
      drawer: const SideMenu(current: SideMenuSection.mainMenu),
      body: Column(
        children: [
          const SizedBox(height: 32),
          Image.asset('assets/images/logo.png', height: 120),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              padding: const EdgeInsets.all(8),
              children: [
                _MenuCard(
                  title: 'Liberação de máquina (FOR007)',
                  onTap: () => open(context, const PreparacaoPage()),
                ),
                _MenuCard(
                  title: 'Amostragem (FOR009)',
                  onTap: () => open(context, const OperadorPage()),
                ),
                _MenuCard(
                  title: 'Finalização de OS (FOR008)',
                  onTap: () => open(context, const FinalizarOsPage()),
                ),
                _MenuCard(
                  title: 'Administração',
                  onTap: () => open(context, MainScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
