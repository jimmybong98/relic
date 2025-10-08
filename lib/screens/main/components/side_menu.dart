// Side menu for navigation across application sections
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/features/preparacao/presentation/preparacao_page.dart';
import 'package:admin/features/operador/presentation/operador_page.dart';
import 'package:admin/features/finalizar_os/presentation/finalizar_os_page.dart';
import 'package:admin/features/cadastro_itens/presentation/cadastro_itens_page.dart';
import 'package:admin/features/export_relatorios/presentation/export_relatorios_page.dart';
import 'package:admin/features/export_relatorios/presentation/status_os_page.dart';
import 'package:admin/features/export_relatorios/presentation/tempo_os_page.dart';
import 'package:admin/features/export_relatorios/presentation/relatorios_insights_page.dart';
import 'package:admin/features/cadastro_maquinas/presentation/cadastro_maquinas_page.dart';
import 'package:admin/features/login/login_page.dart';
import 'package:admin/features/users/users_page.dart';
import 'package:admin/services/auth_service.dart';
import 'package:admin/features/shared/providers/search_flow_form_provider.dart';

enum SideMenuSection {
  mainMenu,
  dashboard,
  preparador,
  operador,
  finalizar,
  checklistLiberacao,
}

class SideMenu extends ConsumerWidget {
  const SideMenu({super.key, required this.current});

  final SideMenuSection current;

  bool _isFlowPage(Widget page) {
    return page is PreparacaoPage ||
        page is OperadorPage ||
        page is FinalizarOsPage;
  }

  String _flowLockedMessage(SharedSearchFormState shared) {
    final osAtual = shared.os.trim();
    if (shared.requiresChecklist) {
      final motivo = (shared.checklistReason ?? '').trim();
      final buffer = StringBuffer('Checklist inicial pendente');
      if (osAtual.isNotEmpty) {
        buffer.write(' para a O.S. $osAtual');
      }
      buffer.write('.');
      if (motivo.isNotEmpty) {
        buffer.write(' Motivo: $motivo.');
      }
      buffer.write(
        ' Preencha o checklist inicial antes de retomar a amostragem.',
      );
      return buffer.toString();
    }
    return osAtual.isEmpty
        ? 'Finalize a O.S. em andamento antes de iniciar outra.'
        : 'Finalize a O.S. $osAtual antes de iniciar outra.';
  }

  void _showFlowLockedMessage(
    BuildContext context,
    SharedSearchFormState shared,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_flowLockedMessage(shared))));
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    Widget page, {
    bool allowDuringActiveFlow = false,
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final shared = ref.read(sharedSearchFormProvider);
    final hasActiveFlow = shared.isActive;
    final flowPage = _isFlowPage(page);
    final shouldIgnoreLock =
        allowDuringActiveFlow && hasActiveFlow && !flowPage;

    if (hasActiveFlow && !flowPage && !shouldIgnoreLock) {
      navigator.pop();
      _showFlowLockedMessage(context, shared);
      return;
    }

    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasActiveFlow || (!flowPage && !shouldIgnoreLock)) {
        ref.read(sharedSearchFormProvider.notifier).clear();
      }
      navigator.push(MaterialPageRoute(builder: (_) => page));
    });
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final shared = ref.read(sharedSearchFormProvider);
    final messenger = ScaffoldMessenger.of(context);
    final message = shared.isActive ? _flowLockedMessage(shared) : null;
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!shared.isActive) {
        ref.read(sharedSearchFormProvider.notifier).clear();
      }
      navigator.popUntil((route) => route.isFirst);
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[
      DrawerListTile(
        title: 'Menu Principal',
        svgSrc: 'assets/icons/menu_dashboard.svg',
        press: () => _goHome(context, ref),
      ),
    ];

    if (current == SideMenuSection.dashboard) {
      items.addAll([
        DrawerListTile(
          title: 'Exportar relatórios',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, ref, const ExportRelatoriosPage()),
        ),
        DrawerListTile(
          title: 'Tempo por OS',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, ref, const TempoOsPage()),
        ),
        DrawerListTile(
          title: 'Insights de relatórios',
          svgSrc: 'assets/icons/menu_doc.svg',
          press: () => _navigate(context, ref, const RelatoriosInsightsPage()),
        ),
      ]);
    }
    switch (current) {
      case SideMenuSection.dashboard:
        items.addAll([
          DrawerListTile(
            title: 'Cadastro/Edição de itens',
            svgSrc: 'assets/icons/menu_store.svg',
            press: () => _navigate(context, ref, const CadastroItensPage()),
          ),
          DrawerListTile(
            title: 'Cadastro de Máquinas',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, ref, CadastroMaquinasPage()),
          ),
          DrawerListTile(
            title: 'Gerenciar Acessos',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, ref, const UsersPage()),
          ),
        ]);
        break;
      case SideMenuSection.preparador:
        items.addAll([
          DrawerListTile(
            title: 'Amostragem',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, ref, const OperadorPage()),
          ),
          DrawerListTile(
            title: 'Finalização de OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, ref, const FinalizarOsPage()),
          ),
        ]);
        break;
      case SideMenuSection.operador:
        items.addAll([
          DrawerListTile(
            title: 'Liberação de máquina',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, ref, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Finalização de OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, ref, const FinalizarOsPage()),
          ),
        ]);
        break;
      case SideMenuSection.finalizar:
        items.addAll([
          DrawerListTile(
            title: 'Liberação de máquina',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, ref, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Amostragem',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, ref, const OperadorPage()),
          ),
        ]);
        break;
      case SideMenuSection.mainMenu:
        items.addAll([
          DrawerListTile(
            title: 'Liberação de máquina',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, ref, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Amostragem',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, ref, const OperadorPage()),
          ),
          DrawerListTile(
            title: 'Finalização de OS',
            svgSrc: 'assets/icons/menu_doc.svg',
            press: () => _navigate(context, ref, const FinalizarOsPage()),
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
              _navigate(
                context,
                ref,
                const StatusOsPage(),
                allowDuringActiveFlow: true,
              );
            },
          ),
        ]);
        break;
      case SideMenuSection.checklistLiberacao:
        items.addAll([
          DrawerListTile(
            title: 'Liberação de máquina',
            svgSrc: 'assets/icons/menu_setting.svg',
            press: () => _navigate(context, ref, const PreparacaoPage()),
          ),
          DrawerListTile(
            title: 'Amostragem',
            svgSrc: 'assets/icons/menu_profile.svg',
            press: () => _navigate(context, ref, const OperadorPage()),
          ),
        ]);
        break;
    }

    return Drawer(
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: SizedBox(
              width: 150,
              height: 75,
              child: SvgPicture.asset(
                'assets/icons/Reliclimpo.svg',
                fit: BoxFit.contain,
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
