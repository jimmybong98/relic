// Side menu for navigation across application sections
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/features/preparacao/presentation/preparacao_page.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/features/finalizar_os/presentation/finalizar_os_page.dart';
import 'package:admin/features/cadastro_itens/presentation/cadastro_itens_page.dart';
import 'package:admin/features/cadastro_preparadores/presentation/cadastro_preparadores_page.dart';
import 'package:admin/features/export_relatorios/presentation/export_relatorios_page.dart';
import 'package:admin/features/export_relatorios/presentation/visualizar_relatorios_page.dart';
import 'package:admin/features/export_relatorios/presentation/tempo_os_page.dart';
import 'package:admin/features/cadastro_maquinas/presentation/cadastro_maquinas_page.dart';
import 'package:admin/features/login/login_page.dart';
import 'package:admin/features/users/users_page.dart';
import 'package:admin/services/auth_service.dart';
import 'package:admin/screens/main/main_screen.dart';

enum SideMenuSection { mainMenu, dashboard, preparador, operador, finalizar }

class SideMenu extends ConsumerWidget {
  const SideMenu({super.key, required this.current});

  final SideMenuSection current;

  void _navigate(BuildContext context, Widget page) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.push(MaterialPageRoute(builder: (_) => page));
    });
  }

  void _goHome(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[
      DrawerListTile(
        title: 'Menu Principal',
        svgSrc: 'assets/icons/menu_dashboard.svg',
        press: () => _goHome(context),
      ),
    ];

    if (current == SideMenuSection.dashboard) {
      items.addAll([
        DrawerListTile(
          title: 'Exportar relatórios',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, const ExportRelatoriosPage()),
        ),
        DrawerListTile(
          title: 'Visualizar relatórios',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, const VisualizarRelatoriosPage()),
        ),
        DrawerListTile(
          title: 'Tempo por OS',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, const TempoOsPage()),
        ),
      ]);
    }

    switch (current) {
      case SideMenuSection.dashboard:
        items.addAll([
          DrawerListTile(
            title: 'Cadastro/Edição de itens',
            svgSrc: 'assets/icons/menu_store.svg',
            press: () => _navigate(context, const CadastroItensPage()),
          ),
          DrawerListTile(
            title: 'Cadastro de Preparadores',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const CadastroPreparadoresPage()),
          ),
          DrawerListTile(
            title: 'Cadastro de Máquinas',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, CadastroMaquinasPage()),
          ),
          DrawerListTile(
            title: 'Gerenciar Acessos',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const UsersPage()),
          ),
        ]);
        break;
      case SideMenuSection.preparador:
        items.addAll([
          DrawerListTile(
            title: 'Operador',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const OperadorPage()),
          ),
          DrawerListTile(
            title: 'Finalizar OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, const FinalizarOsPage()),
          ),
        ]);
        break;
      case SideMenuSection.operador:
        items.addAll([
          DrawerListTile(
            title: 'Preparador',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Finalizar OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, const FinalizarOsPage()),
          ),
        ]);
        break;
      case SideMenuSection.finalizar:
        items.addAll([
          DrawerListTile(
            title: 'Preparador',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Operador',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const OperadorPage()),
          ),
        ]);
        break;
      case SideMenuSection.mainMenu:
        items.addAll([
          DrawerListTile(
            title: 'Preparador',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Operador',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const OperadorPage()),
          ),
          DrawerListTile(
            title: 'Finalizar OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, const FinalizarOsPage()),
          ),
          DrawerListTile(
            title: 'Supervisão',
            svgSrc: 'assets/icons/menu_task.svg',
            press: () async {
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
              _navigate(context, MainScreen());
            },
          ),
        ]);
    }

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Image.asset('assets/images/traco.png'),
          ...items,
        ],
      ),
    );
  }
}

class DrawerListTile extends StatelessWidget {
  const DrawerListTile({
    super.key,
    required this.title,
    required this.svgSrc,
    required this.press,
  });

  final String title;
  final String svgSrc;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: press,
      horizontalTitleGap: 0.0,
      leading: SvgPicture.asset(
        svgSrc,
        colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn),
        height: 16,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white54)),
    );
  }
}
