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
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Principal')),
      drawer: const SideMenu(current: SideMenuSection.mainMenu),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PreparacaoPage(),
                  ),
                );
              },
              child: const Text('Preparador'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OperadorPage(),
                  ),
                );
              },
              child: const Text('Operador'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FinalizarOsPage(),
                  ),
                );
              },
              child: const Text('Finalizar OS'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MainScreen(),
                  ),
                );
              },
              child: const Text('Supervisão'),
            ),
          ],
        ),
      ),
    );
  }
}
