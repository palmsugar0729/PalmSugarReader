import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// 顶部菜单栏按钮数据
class TopMenuButton {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const TopMenuButton({
    required this.tooltip,
    required this.icon,
    this.enabled = true,
    this.onPressed,
  });
}

/// 顶部自动隐藏菜单栏 — 鼠标移到顶部时滑出，离开后收起
///
/// 用法：
/// ```dart
/// TopMenuOverlay(
///   buttons: [
///     TopMenuButton(tooltip: '标注', icon: Icons.edit, onPressed: () {}),
///     TopMenuButton(tooltip: '设置', icon: Icons.settings, onPressed: () {}),
///   ],
///   child: Scaffold(...),
/// )
/// ```
class TopMenuOverlay extends StatefulWidget {
  final List<TopMenuButton> buttons;
  final Widget child;

  const TopMenuOverlay({
    super.key,
    required this.buttons,
    required this.child,
  });

  @override
  State<TopMenuOverlay> createState() => _TopMenuOverlayState();
}

class _TopMenuOverlayState extends State<TopMenuOverlay> {
  bool _showMenu = false;
  Timer? _hideTimer;

  static const double _triggerHeight = 5; // 顶部触发区高度
  static const double _menuHeight = 44; // 菜单栏高度
  static const double _hideZone = 60; // 超出此高度则开始隐藏计时

  void _onHover(PointerHoverEvent event) {
    final dy = event.localPosition.dy;

    if (dy <= _triggerHeight) {
      // 鼠标进入顶部触发区 → 立即显示
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_showMenu) setState(() => _showMenu = true);
    } else if (dy > _hideZone && _showMenu && _hideTimer == null) {
      // 鼠标离开菜单区域 → 延时隐藏
      _hideTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showMenu = false);
        _hideTimer = null;
      });
    } else if (dy <= _hideZone && _hideTimer != null) {
      // 鼠标回到菜单区域 → 取消隐藏
      _hideTimer!.cancel();
      _hideTimer = null;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    // ── 移动端：菜单按钮由各页面自行放入 AppBar.actions，此处只透传 ──
    if (_isMobile) {
      return widget.child;
    }

    // ── 桌面端：hover 顶部滑出 ──
    return MouseRegion(
      onHover: _onHover,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              offset: _showMenu ? Offset.zero : const Offset(0, -1),
              child: _buildMenuBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBar() {
    return Container(
      height: _menuHeight,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.buttons.map((btn) {
          return _MenuBarButton(
            tooltip: btn.tooltip,
            icon: btn.icon,
            enabled: btn.enabled,
            onPressed: btn.onPressed,
          );
        }).toList(),
      ),
    );
  }
}

/// 菜单栏单个按钮
class _MenuBarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _MenuBarButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.textPrimary : AppTheme.textSecondary.withAlpha(100);

    return Tooltip(
      message: tooltip,
      verticalOffset: 36,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: color,
          onPressed: enabled ? onPressed : null,
          splashRadius: 18,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
