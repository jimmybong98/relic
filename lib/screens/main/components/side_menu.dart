// Side menu for navigation across application sections
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin/features/preparacao/presentation/preparacao_page.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/screens/main/main_screen.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

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
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Image.asset('assets/images/logo.png'),
          ),
          DrawerListTile(
            title: 'Menu Principal',
            svgSrc: 'assets/icons/menu_dashboard.svg',
            press: () => _goHome(context),
          ),
          DrawerListTile(
            title: 'Supervisão',
            svgSrc: 'assets/icons/menu_dashboard.svg',
            press: () => _navigate(context, MainScreen()),
          ),
          DrawerListTile(
            title: 'Preparador',
            svgSrc: 'assets/icons/menu_task.svg',
            press: () => _navigate(context, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Operador',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, const OperadorPage()),
          ),

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