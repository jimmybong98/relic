import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Custom title bar with window controls and drag support.
class WindowBar extends StatefulWidget implements PreferredSizeWidget {
  const WindowBar({super.key, this.title, this.actions});

  final String? title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  State<WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<WindowBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _syncMaximized();
  }

  Future<void> _syncMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
            if (widget.title != null)
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            const Spacer(),
            if (widget.actions != null) ...widget.actions!,
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
}
