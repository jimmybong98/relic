// lib/widgets/side_menu.dart  (ajuste o caminho conforme seu projeto)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Ajuste estes imports para o caminho correto no seu app:
import 'package:admin/features/preparacao/presentation/preparacao_page.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/screens/main/main_screen.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({Key? key}) : super(key: key);

  void _go(BuildContext context, Widget page) {
    // Usa o Navigator raiz para evitar travamentos ao fechar o Drawer
    final navigator = Navigator.of(context, rootNavigator: true);
    // Fecha o Drawer
    navigator.pop();
    // Aguarda o próximo frame antes de navegar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.push(
        MaterialPageRoute(builder: (_) => page),
      );
    });
  }

  void _goHome(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    // Após fechar o Drawer, volta à primeira rota (Menu Principal)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.popUntil((route) => route.isFirst);
    });

      navigator.push(
        MaterialPageRoute(builder: (_) => page),
      );
    });
  }

  void _goHome(BuildContext context) {
            press: () => _goHome(context),
          ),
          DrawerListTile(
            title: "Supervisão",
            svgSrc: "assets/icons/menu_dashboard.svg",
            press: () => _go(context, MainScreen()),
      navigator.popUntil((route) => route.isFirst);
    });

  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Image.asset("assets/images/logo.png"),
          ),
          DrawerListTile(
            title: "Menu Principal",
            svgSrc: "assets/icons/menu_dashboard.svg",
            press: () => _goHome(context),

          ),
          DrawerListTile(
            title: "Supervisão",
            svgSrc: "assets/icons/menu_dashboard.svg",
            press: () => _go(context, MainScreen()),

          ),
          DrawerListTile(
            title: "Supervisão",
            svgSrc: "assets/icons/menu_dashboard.svg",
            press: () => _go(context, MainScreen()),

          ),
          DrawerListTile(
            title: "Supervisão",
            svgSrc: "assets/icons/menu_dashboard.svg",
            press: () => _go(context, MainScreen()),
          ),
            DrawerListTile(
              title: "Supervisão",
              svgSrc: "assets/icons/menu_dashboard.svg",
              press: () => _go(context, MainScreen()),
            ),

          // ====== SEÇÕES DO SEU SISTEMA ======
          DrawerListTile(
            title: "Preparador",
            svgSrc: "assets/icons/menu_task.svg",
            press: () => _go(context, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: "Operador",
            svgSrc: "assets/icons/menu_profile.svg",
            press: () => _go(context, const OperadorPage()),
          ),

          // (demais itens do template — mantenha/ajuste como quiser)
          DrawerListTile(
            title: "Transaction",
            svgSrc: "assets/icons/menu_tran.svg",
            press: () {},
          ),
          DrawerListTile(
            title: "Documents",
            svgSrc: "assets/icons/menu_doc.svg",
            press: () {},
          ),
          DrawerListTile(
            title: "Store",
            svgSrc: "assets/icons/menu_store.svg",
            press: () {},
          ),
          DrawerListTile(
            title: "Notification",
            svgSrc: "assets/icons/menu_notification.svg",
            press: () {},
          ),
          DrawerListTile(
            title: "Settings",
            svgSrc: "assets/icons/menu_setting.svg",
            press: () {},
          ),
        ],
      ),
    );
  }
}

class DrawerListTile extends StatelessWidget {
  const DrawerListTile({
    Key? key,
    required this.title,
    required this.svgSrc,
    required this.press,
  }) : super(key: key);

  final String title, svgSrc;
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
