import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';
import 'package:admin/utils/platform_utils.dart';
import 'package:admin/widgets/profile_button.dart';

/// Custom title bar with window controls and drag support.
class WindowBar extends StatefulWidget implements PreferredSizeWidget {
  const WindowBar({
    super.key,
    this.title,
    this.titleSvgAsset,
    this.actions,
    this.showMenu = false,
    this.showProfile = true,
  });

  final String? title;
  final String? titleSvgAsset;
  final List<Widget>? actions;
  final bool showMenu;
  final bool showProfile;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<WindowBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      _syncMaximized();
    }
  }

  Future<void> _syncMaximized() async {
    if (!isDesktop) return;
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return AppBar(
        toolbarHeight: widget.preferredSize.height,
        title: widget.title != null ? _buildTitle(context) : null,
        actions: [
          if (widget.actions != null) ...widget.actions!,
          if (widget.showProfile) const ProfileButton(),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        _isMaximized
            ? await windowManager.unmaximize()
            : await windowManager.maximize();
        _syncMaximized();
      },
      child: Container(
        height: widget.preferredSize.height,
        color: const Color(0xFF2D2F33),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (widget.showMenu)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).openAppDrawerTooltip,
                ),
              ),
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildTitle(
                  context,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            const Spacer(),
            if (widget.actions != null) ...widget.actions!,
            if (widget.showProfile) const ProfileButton(),
            _buildButton(Icons.remove, () => windowManager.minimize()),
            _buildButton(
              _isMaximized ? Icons.filter_none : Icons.crop_square,
              () async {
                _isMaximized
                    ? await windowManager.unmaximize()
                    : await windowManager.maximize();
                _syncMaximized();
              },
            ),
            _buildButton(Icons.close, () => windowManager.close()),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 16),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed,
    );
  }

  Widget _buildTitle(BuildContext context, {TextStyle? style}) {
    final textWidget = Text(widget.title!, style: style);

    if (widget.titleSvgAsset == null) {
      return textWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(widget.titleSvgAsset!, height: 20, width: 20),
        const SizedBox(width: 8),
        textWidget,
      ],
    );
  }
}
