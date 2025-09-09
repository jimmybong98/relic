import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/screens/main/main_screen.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';
import '../login/login_page.dart';
import '../../services/auth_service.dart';

class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(BuildContext context, Widget page) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    Future<void> openAdmin() async {
      var auth = ref.read(authServiceProvider);
      if (auth == null) {
        final ok = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
        if (ok != true) return;
        auth = ref.read(authServiceProvider);
      }
      if (auth == null || !auth.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso restrito a administradores')),
        );
        return;
      }
      open(context, MainScreen());
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
            child: SingleChildScrollView(
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _MenuImageButton(
                      image: 'assets/images/FOR007.png',
                      onPressed: () => open(context, const PreparacaoPage()),
                    ),
                    _MenuImageButton(
                      image: 'assets/images/Amostragem.png',
                      onPressed: () => open(context, const OperadorPage()),
                    ),
                    _MenuImageButton(
                      image: 'assets/images/FOR008.png',
                      onPressed: () => open(context, const OperadorPage()),
                    ),
                    _MenuImageButton(
                      image: 'assets/images/dashboard.png',
                      onPressed: openAdmin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuImageButton extends StatelessWidget {
  const _MenuImageButton({required this.image, required this.onPressed});

  final String image;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(image, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
