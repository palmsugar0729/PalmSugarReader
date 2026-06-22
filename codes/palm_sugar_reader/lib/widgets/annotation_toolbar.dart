import 'dart:io';

import 'package:flutter/material.dart';

import '../models/annotation.dart';
import '../theme.dart';

/// 工具栏配置（由 AnnotationToolbar 管理，通过 onChanged 向外报告）
class AnnotationToolConfig {
  AnnotationType tool;
  int brushType; // 0=pencil, 1=pen, 2=watercolor（仅 freeform 有效）
  Color color;
  double opacity;
  double thickness;
  bool allowFingerDraw;

  AnnotationToolConfig({
    this.tool = AnnotationType.freeform,
    this.brushType = 1,
    this.color = const Color(0xFF000000),
    this.opacity = 1.0,
    this.thickness = 8,
    this.allowFingerDraw = false,
  });

  AnnotationToolConfig copy() => AnnotationToolConfig(
        tool: tool,
        brushType: brushType,
        color: color,
        opacity: opacity,
        thickness: thickness,
        allowFingerDraw: allowFingerDraw,
      );
}

/// GoodNotes 风格的常驻浮动标注工具栏
///
/// 展开态：两行布局（工具行 + 颜色/粗细行）
/// 收起态：44x44 圆形浮动按钮
///
/// 仅在移动端（Android/iOS）使用，桌面端保留 Dialog 流程
class AnnotationToolbar extends StatefulWidget {
  final AnnotationToolConfig initialConfig;
  final ValueChanged<AnnotationToolConfig> onChanged;
  final VoidCallback onUndo;
  final VoidCallback onExit;

  const AnnotationToolbar({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    required this.onUndo,
    required this.onExit,
  });

  /// 是否应该使用工具栏模式（移动端 true，桌面端 false）
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  State<AnnotationToolbar> createState() => _AnnotationToolbarState();
}

class _AnnotationToolbarState extends State<AnnotationToolbar>
    with SingleTickerProviderStateMixin {
  late AnnotationToolConfig _cfg;
  bool _collapsed = false;

  // ── 预设 ──

  static const _presetColors = [
    Color(0xFF000000), // 黑
    Color(0xFFFFEB3B), // 黄
    Color(0xFF4CAF50), // 绿
    Color(0xFF2196F3), // 蓝
    Color(0xFFE91E63), // 粉
    Color(0xFFFF9800), // 橙
  ];

  static const _brushDefs = [
    (icon: Icons.edit, label: '铅笔', type: 0),
    (icon: Icons.brush, label: '画笔', type: 1),
    (icon: Icons.water_drop, label: '水彩', type: 2),
  ];

  static const _thicknessPresets = [
    (label: 'S', value: 3.0),
    (label: 'M', value: 8.0),
    (label: 'L', value: 16.0),
  ];

  @override
  void initState() {
    super.initState();
    _cfg = widget.initialConfig.copy();
  }

  void _emit() => widget.onChanged(_cfg.copy());

  void _setTool(AnnotationType t) {
    setState(() => _cfg.tool = t);
    _emit();
  }

  void _setBrush(int bt) {
    setState(() {
      _cfg.tool = AnnotationType.freeform;
      _cfg.brushType = bt;
    });
    _emit();
  }

  void _setColor(Color c) {
    setState(() => _cfg.color = c);
    _emit();
  }

  void _setThickness(double t) {
    setState(() => _cfg.thickness = t);
    _emit();
  }

  // ── "更多" bottom sheet ──

  void _showMore() {
    final hexCtl =
        TextEditingController(text: _colorToHex(_cfg.color));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽把手
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // HEX 输入
                  Row(children: [
                    const Text('HEX:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      height: 32,
                      child: TextField(
                        controller: hexCtl,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final t = v.trim();
                          if (t.length == 7 && t.startsWith('#')) {
                            try {
                              final r = int.parse(t.substring(1, 3),
                                  radix: 16);
                              final g = int.parse(t.substring(3, 5),
                                  radix: 16);
                              final b = int.parse(t.substring(5, 7),
                                  radix: 16);
                              final c = Color.fromARGB(255, r, g, b);
                              setSheetState(() => _cfg.color = c);
                              setState(() => _cfg.color = c);
                              _emit();
                            } catch (_) {}
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _cfg.color
                            .withValues(alpha: _cfg.opacity),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // 不透明度
                  Row(children: [
                    const Text('不透明:', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: _cfg.opacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        activeColor: _cfg.color,
                        onChanged: (v) {
                          setSheetState(() => _cfg.opacity = v);
                          setState(() => _cfg.opacity = v);
                          _emit();
                        },
                      ),
                    ),
                    Text('${(_cfg.opacity * 100).round()}%',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  // 粗细
                  Row(children: [
                    const Text('粗细:', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: _cfg.thickness,
                        min: 2,
                        max: 40,
                        divisions: 19,
                        activeColor: AppTheme.primaryDark,
                        onChanged: (v) {
                          setSheetState(() => _cfg.thickness = v);
                          setState(() => _cfg.thickness = v);
                          _emit();
                        },
                      ),
                    ),
                    Text('${_cfg.thickness.round()}px',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                  const SizedBox(height: 16),
                  // 手指书写开关
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许手指书写',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('关闭后仅响应触控笔',
                        style: TextStyle(fontSize: 11)),
                    value: _cfg.allowFingerDraw,
                    dense: true,
                    onChanged: (v) {
                      setSheetState(() => _cfg.allowFingerDraw = v);
                      setState(() => _cfg.allowFingerDraw = v);
                      _emit();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  // ── 构建 ──

  @override
  Widget build(BuildContext context) {
    if (_collapsed) return _buildCollapsed();
    return _buildExpanded();
  }

  Widget _buildCollapsed() {
    return GestureDetector(
      onTap: () => setState(() => _collapsed = false),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _cfg.color.withValues(alpha: _cfg.opacity),
              shape: BoxShape.circle,
              border: Border.all(color: _cfg.color, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final isFreeform = _cfg.tool == AnnotationType.freeform ||
        _cfg.tool == AnnotationType.eraser;
    final isEraser = _cfg.tool == AnnotationType.eraser;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 第一行：工具切换 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 笔刷按钮
                ..._brushDefs.map((b) => _ToolBtn(
                      icon: b.icon,
                      label: b.label,
                      active: isFreeform &&
                          !isEraser &&
                          _cfg.brushType == b.type,
                      onTap: () => _setBrush(b.type),
                    )),
                _sep(),
                // 荧光笔
                _ToolBtn(
                  icon: Icons.format_paint,
                  label: '荧光笔',
                  active: _cfg.tool == AnnotationType.highlight,
                  onTap: () => _setTool(AnnotationType.highlight),
                ),
                // 橡皮擦
                _ToolBtn(
                  icon: Icons.auto_fix_high,
                  label: '橡皮',
                  active: isEraser,
                  onTap: () => _setTool(AnnotationType.eraser),
                ),
                // 便签
                _ToolBtn(
                  icon: Icons.note_add,
                  label: '便签',
                  active: _cfg.tool == AnnotationType.note,
                  onTap: () => _setTool(AnnotationType.note),
                ),
                _sep(),
                // 撤销
                _MiniBtn(
                  icon: Icons.undo,
                  tooltip: '撤销',
                  onTap: widget.onUndo,
                ),
                const SizedBox(width: 4),
                // 收起
                _MiniBtn(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: '收起',
                  onTap: () => setState(() => _collapsed = true),
                ),
                const SizedBox(width: 2),
                // 退出
                _MiniBtn(
                  icon: Icons.close,
                  tooltip: '退出标注',
                  onTap: widget.onExit,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── 第二行：颜色 + 粗细 + 更多 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 预设色块
                ..._presetColors.map((c) {
                  final sel = c.toARGB32() == _cfg.color.toARGB32();
                  return GestureDetector(
                    onTap: () => _setColor(c),
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: _cfg.opacity),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel
                              ? AppTheme.primaryDark
                              : Colors.grey.shade300,
                          width: sel ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // 粗细预设
                ..._thicknessPresets.map((tp) {
                  final sel = _cfg.thickness == tp.value;
                  return GestureDetector(
                    onTap: () => _setThickness(tp.value),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primaryLight.withAlpha(80)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primaryDark
                              : Colors.grey.shade300,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(tp.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              color: sel
                                  ? AppTheme.primaryDark
                                  : Colors.grey.shade600,
                            )),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                // 更多
                _MiniBtn(
                  icon: Icons.tune,
                  tooltip: '更多设置',
                  onTap: _showMore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sep() =>
      Container(width: 1, height: 24, color: Colors.grey.shade300);
}

// ── 工具按钮 ──

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryLight.withAlpha(60) : null,
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(color: AppTheme.primaryDark, width: 1.5)
              : null,
        ),
        child: Tooltip(
          message: label,
          child: Icon(icon,
              size: 20,
              color: active ? AppTheme.primaryDark : Colors.grey.shade600),
        ),
      ),
    );
  }
}

// ── 小按钮 ──

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 18),
          color: Colors.grey.shade600,
          onPressed: onTap,
          splashRadius: 14,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
