import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/screens/main/main_screen.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';
import '../finalizar_os/presentation/finalizar_os_page.dart';
import '../login/login_page.dart';
import '../../services/auth_service.dart';

class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(BuildContext context, Widget page) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    return Scaffold(
      appBar: const WindowBar(title: 'Menu Principal', showMenu: true),
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
                  onTap: () async {
                    var auth = ref.read(authServiceProvider);
                    if (auth == null) {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                      if (ok != true) return;
                      auth = ref.read(authServiceProvider);
                    }
                    if (auth == null || !auth.isAdmin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acesso restrito a administradores'),
                        ),
                      );
                      return;
                    }
                    open(context, MainScreen());
                  },
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
