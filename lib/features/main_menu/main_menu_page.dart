import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:admin/constants.dart';
import 'package:admin/features/export_relatorios/presentation/status_os_page.dart';
import 'package:admin/screens/main/components/side_menu.dart';
import 'package:admin/widgets/window_bar.dart';
import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';
import '../login/login_page.dart';
import '../../services/auth_service.dart';
import '../finalizar_os/presentation/finalizar_os_page.dart';
import '../shared/providers/search_flow_form_provider.dart';

class MainMenuPage extends ConsumerStatefulWidget {
  const MainMenuPage({super.key});

  @override
  ConsumerState<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends ConsumerState<MainMenuPage> {
  // Removidos: _logoIndex, _timer, _logos, initState e dispose

  @override
  Widget build(BuildContext context) {
    void showFlowLockedMessage(SharedSearchFormState shared) {
      final osAtual = shared.os.trim();
      final mensagem = osAtual.isEmpty
          ? 'Finalize a O.S. em andamento antes de iniciar outra.'
          : 'Finalize a O.S. $osAtual antes de iniciar outra.';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(mensagem)));
    }

    void openFlowPage(Widget page) {
      final shared = ref.read(sharedSearchFormProvider);
      if (!shared.isActive) {
        ref.read(sharedSearchFormProvider.notifier).clear();
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    Future<void> openAdmin() async {
      final shared = ref.read(sharedSearchFormProvider);
      if (shared.isActive) {
        showFlowLockedMessage(shared);
      } else {
        ref.read(sharedSearchFormProvider.notifier).clear();
      }
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StatusOsPage()));
    }

    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isPortrait = size.height >= size.width;
    final isPhonePortrait = size.width < 640 && isPortrait;
    final isTabletWidth = size.width >= 640 && size.width < 1024;
    final double horizontalPadding = isPhonePortrait ? 20 : 24;
    final double topPadding = isPhonePortrait ? 24 : (isTabletWidth ? 140 : 48);
    final double bottomPadding = isPhonePortrait ? 24 : 48;
    final double dividerHeight = isPhonePortrait ? 10 : 15;
    final entries = [
      _MenuEntry(
        title: 'Preparador',
        description:
        'Organize recursos, prepare itens e acompanhe o fluxo inicial.',
        iconAsset: 'assets/icons/FOR007.svg',
        accentColor: primaryColor,
        onTap: () => openFlowPage(const PreparacaoPage()),
      ),
      _MenuEntry(
        title: 'Operador',
        description:
        'Registre atividades de produção e mantenha o time sincronizado.',
        iconAsset: 'assets/icons/Amostragem.svg',
        accentColor: const Color(0xFFF6A560),
        onTap: () => openFlowPage(const OperadorPage()),
      ),
      _MenuEntry(
        title: 'Finalizar OS',
        description:
        'Conclua ordens de serviço garantindo rastreabilidade.',
        iconAsset: 'assets/icons/FOR008.svg',
        accentColor: const Color(0xFF8E7CFF),
        onTap: () => openFlowPage(const FinalizarOsPage()),
      ),
      _MenuEntry(
        title: 'Supervisão',
        description:
        'Visualize indicadores e relatórios estratégicos em tempo real.',
        iconAsset: 'assets/icons/Dashboard.svg',
        accentColor: accentColor,
        onTap: () => openAdmin(),
        semanticLabel: 'Acessar supervisão e dashboards',
      ),
    ];

    return Scaffold(
      appBar: const WindowBar(title: 'Menu Principal', showMenu: true),
      drawer: const SideMenu(current: SideMenuSection.mainMenu),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10121C), Color(0xFF151A24), Color(0xFF1E2332)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -120,
                left: -70,
                child: _DecorativeBlob(
                  size: 260,
                  colors: [Color(0x552697FF), Color(0x332697FF)],
                ),
              ),
              const Positioned(
                bottom: -160,
                right: -90,
                child: _DecorativeBlob(
                  size: 320,
                  colors: [Color(0x554DD0E1), Color(0x334DD0E1)],
                ),
              ),

              // Logos flutuando sobre as bolhas (Opção 2)
              if (!isPhonePortrait)
                Positioned(
                  top: isTabletWidth ? 32 : 20,
                  left: isTabletWidth ? 20 : 20,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Opacity(
                      opacity: 1,
                      child: Image.asset(
                        'assets/images/logotuptech1.png',
                        width: isTabletWidth ? 150 : 150,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: isPhonePortrait ? -12 : 20,
                bottom: isPhonePortrait ? -12 : 20,
                child: IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 1,
                    child: Image.asset(
                      'assets/images/Relictt.png',
                      width: isPhonePortrait ? 150 : 150,
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.topCenter,
                child: LayoutBuilder(
                  builder: (context, _) {
                    final padding = EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    );

                    if (isPhonePortrait) {
                      return Padding(
                        padding: padding,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildIntroSection(theme, forceCenter: true),
                                  const SizedBox(height: 20),
                                  Image.asset(
                                    'assets/images/traco.png',
                                    height: dividerHeight,
                                  ),
                                  const SizedBox(height: 20),
                                  _MenuGrid(
                                    entries: entries,
                                    forceColumn: true,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: padding,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIntroSection(theme),
                            const SizedBox(height: 24),
                            Image.asset(
                              'assets/images/traco.png',
                              height: dividerHeight,
                            ),
                            const SizedBox(height: 32),
                            _MenuGrid(entries: entries),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection(ThemeData theme, {bool forceCenter = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldCenter = forceCenter || constraints.maxWidth < 500;
        final titleStyle = theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
        final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
        );

        final headline = <Widget>[
          Text(
            'Bem-vindo ao RELIC - Controle de qualidade',
            textAlign: shouldCenter ? TextAlign.center : TextAlign.start,
            style: titleStyle,
          ),
          const SizedBox(height: 12),
          Text(
            'Selecione o módulo desejado para iniciar o seu fluxo de trabalho.',
            textAlign: shouldCenter ? TextAlign.center : TextAlign.start,
            style: subtitleStyle,
          ),
        ];

        if (shouldCenter) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!forceCenter) const SizedBox(height: 24),
              ...headline,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: headline,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.onTap,
    required this.accentColor,
    this.semanticLabel,
  });

  final String title;
  final String description;
  final String iconAsset;
  final VoidCallback onTap;
  final Color accentColor;
  final String? semanticLabel;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.entries, this.forceColumn = false});

  final List<_MenuEntry> entries;
  final bool forceColumn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldUseColumn = forceColumn || constraints.maxWidth < 640;

        if (shouldUseColumn) {
          final spacing = forceColumn ? 16.0 : 20.0;
          double? cardMinHeight;

          if (forceColumn &&
              constraints.hasBoundedHeight &&
              entries.isNotEmpty) {
            final totalSpacing = spacing * (entries.length - 1);
            final heightForCards = constraints.maxHeight - totalSpacing;
            final computed = heightForCards / entries.length;
            if (computed.isFinite && computed > 0) {
              cardMinHeight = computed;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _MenuCard(
                  entry: entries[i],
                  maxWidth: constraints.maxWidth,
                  minHeight: cardMinHeight,
                  isCompact: forceColumn,
                ),
                if (i < entries.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        final width = constraints.maxWidth;
        final double cardWidth = width >= 960 ? 320 : (width / 2) - 16;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: entries
              .map(
                (entry) => _MenuCard(
              entry: entry,
              maxWidth: cardWidth.clamp(260.0, 360.0).toDouble(),
            ),
          )
              .toList(),
        );
      },
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({
    required this.entry,
    required this.maxWidth,
    this.minHeight,
    this.isCompact = false,
  });

  final _MenuEntry entry;
  final double maxWidth;
  final double? minHeight;
  final bool isCompact;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.entry.accentColor;
    final scale = _pressed ? 0.97 : (_hovering ? 1.02 : 1.0);
    final cardPadding = EdgeInsets.all(widget.isCompact ? 20 : 24);
    final iconSize = widget.isCompact ? 32.0 : 36.0;
    final gapAfterIcon = widget.isCompact ? 20.0 : 24.0;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: widget.isCompact ? 18 : null,
    );
    final descriptionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white70,
      fontSize: widget.isCompact ? 14 : null,
    );

    return SizedBox(
      width: widget.maxWidth,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() {
          _hovering = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hovering
                    ? accent.withOpacity(0.55)
                    : Colors.white.withOpacity(0.06),
              ),
              gradient: _hovering
                  ? LinearGradient(
                colors: [
                  accent.withOpacity(0.22),
                  theme.colorScheme.surface.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: _hovering
                  ? null
                  : theme.colorScheme.surface.withOpacity(0.78),
              boxShadow: [
                BoxShadow(
                  color: _hovering
                      ? accent.withOpacity(0.35)
                      : Colors.black.withOpacity(0.45),
                  blurRadius: _hovering ? 34 : 22,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                button: true,
                label: widget.entry.semanticLabel ?? widget.entry.title,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: widget.entry.onTap,
                  onHighlightChanged: (value) =>
                      setState(() => _pressed = value),
                  child: Padding(
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              widget.entry.iconAsset,
                              width: iconSize,
                              height: iconSize,
                            ),
                          ),
                        ),
                        SizedBox(height: gapAfterIcon),
                        Text(widget.entry.title, style: titleStyle),
                        const SizedBox(height: 8),
                        Text(widget.entry.description, style: descriptionStyle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeBlob extends StatelessWidget {
  const _DecorativeBlob({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 140, sigmaY: 140),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: colors,
                center: Alignment.center,
                radius: 0.9,
              ),
            ),
          ),
        ),
      ),
    );
  }
}