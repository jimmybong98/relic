import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin/screens/main/main_screen.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';
import '../login/login_page.dart';
import '../../services/auth_service.dart';
import '../finalizar_os/presentation/finalizar_os_page.dart';


class MainMenuPage extends ConsumerStatefulWidget {
  const MainMenuPage({super.key});

  @override
  ConsumerState<MainMenuPage> createState() => _MainMenuPageState();
}

class _LogoConfig {
  const _LogoConfig({required this.asset, this.width, this.height});

  final String asset;
  final double? width;
  final double? height;
}

class _MainMenuPageState extends ConsumerState<MainMenuPage> {
  int _logoIndex = 0;
  Timer? _timer;
  static const _logos = [
    _LogoConfig(asset: 'assets/images/Relictt.png', width: 250, height: 110),
    _LogoConfig(asset: 'assets/images/logotuptech1.png', width: 250 , height: 110),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() => _logoIndex = 1 - _logoIndex);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final logo = _logos[_logoIndex];
    return Scaffold(
      appBar: const WindowBar(title: 'Menu Principal', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.mainMenu),

      // ====== INÍCIO: Wallpaper (única mudança) ======
      body: Stack(
        children: [
          // Conteúdo principal
          Column(
            children: [
              const SizedBox(height: 10),
              Image.asset('assets/images/traco.png'),
              const SizedBox(height: 0),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      // sem scroll
                      children: [
                        _MenuButton(
                          image: 'assets/icons/FOR007.svg',
                          onPressed: () => open(context, const PreparacaoPage()),
                        ),
                        _MenuButton(
                          image: 'assets/icons/Amostragem.svg',
                          onPressed: () => open(context, const OperadorPage()),
                        ),
                        _MenuButton(
                          image: 'assets/icons/FOR008.svg',
                          onPressed: () => open(context, const FinalizarOsPage()),
                        ),
                        _MenuButton(
                          image: 'assets/icons/Dashboard.svg',
                          onPressed: openAdmin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Logo no canto inferior direito
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Image.asset(
                  logo.asset,
                  key: ValueKey(_logoIndex),
                  height: logo.height,
                  width: logo.width,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({required this.image, required this.onPressed});

  final String image;
  final VoidCallback onPressed;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovering = false;
  bool _pressed = false;

  double get _scale => _pressed ? 0.95 : (_hovering ? 1.05 : 1.0);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final buttonWidth = width < 500 ? width * 0.8 : 300.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: buttonWidth,
          height: 120,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              onHover: (v) => setState(() => _hovering = v),
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: SvgPicture.asset(widget.image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}