import 'package:admin/controllers/menu_app_controller.dart';
import 'package:admin/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/widgets/window_bar.dart';

import 'components/side_menu.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: context.read<MenuAppController>().scaffoldKey,
      appBar: const WindowBar(title: 'Supervisão', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: SafeArea(child: DashboardScreen()),
    );
  }
}
