// Side menu for navigation across application sections
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin/features/preparacao/presentation/preparacao_page.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/features/cadastro_itens/presentation/cadastro_itens_page.dart';
import 'package:admin/features/cadastro_preparadores/presentation/cadastro_preparadores_page.dart';
import 'package:admin/features/export_relatorios/presentation/export_relatorios_page.dart';
import 'package:admin/screens/main/main_screen.dart';

enum SideMenuSection { mainMenu, dashboard, preparador, operador }

class SideMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final items = <Widget>[
      DrawerListTile(
        title: 'Menu Principal',
        svgSrc: 'assets/icons/menu_dashboard.svg',
        press: () => _goHome(context),
      ),
      DrawerListTile(
        title: 'Exportar relatórios',
        svgSrc: 'assets/icons/menu_doc.svg',
        press: () => _navigate(context, const ExportRelatoriosPage()),
      ),
    ];

    switch (current) {
      case SideMenuSection.dashboard:
        items.addAll([
          DrawerListTile(
            title: 'Cadastro de novos itens',
            svgSrc: 'assets/icons/menu_store.svg',
            press: () => _navigate(context, const CadastroItensPage()),
          ),
          DrawerListTile(
            title: 'Cadastro de Preparadores',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () =>
                _navigate(context, const CadastroPreparadoresPage()),
          ),
        ]);
        break;
      case SideMenuSection.preparador:
        items.add(
          DrawerListTile(
            title: 'Operador',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const OperadorPage()),
          ),
        );
        break;
      case SideMenuSection.operador:
        items.add(
          DrawerListTile(
            title: 'Preparador',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, const PreparacaoPage()),
          ),
        );
        break;
      case SideMenuSection.mainMenu:
      default:
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
            title: 'Supervisão',
            svgSrc: 'assets/icons/menu_task.svg',
            press: () => _navigate(context, MainScreen()),
          ),
        ]);
    }

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Image.asset('assets/images/logo.png'),
          ),
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
      title: Text(
        title,
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }
}