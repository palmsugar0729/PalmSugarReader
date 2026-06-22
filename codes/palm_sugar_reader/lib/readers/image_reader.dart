import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';
import '../theme.dart';
import '../widgets/annotation_layer.dart';
import '../widgets/annotation_toolbar.dart';
import '../widgets/color_picker.dart';

class ImageReader extends StatefulWidget {
  final String filePath;
  const ImageReader({super.key, required this.filePath});
  @override
  State<ImageReader> createState() => ImageReaderState();
}

class ImageReaderState extends State<ImageReader> {
  final TransformationController _tc = TransformationController();
  final FocusNode _focusNode = FocusNode();
  double _currentScale = 1.0;
  bool _annotMode = false;
  AnnotationType _tool = AnnotationType.freeform;
  Color _color = const Color(0xFF000000);
  double _opacity = 1.0;
  double _thickness = 8;
  int _brushType = 1; // 默认画笔
  bool _allowFingerDraw = false;
  int _annotRefreshCounter = 0;

  @override
  void dispose() {
    _tc.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 以视口中心为焦点进行缩放，保留已有平移。
  void _applyZoom(double targetScale) {
    final clamped = targetScale.clamp(0.5, 5.0);
    final matrix = _tc.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    if (currentScale == 0) {
      _tc.value = Matrix4.identity();
      _currentScale = 1.0;
      return;
    }
    final scaleDelta = clamped / currentScale;

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final center = Offset(size.width / 2, size.height / 2);

    // 以视口中心为焦点缩放:
    // 新矩阵 = T(center) · S(scaleDelta) · T(-center) · 旧矩阵
    final toCenter = Matrix4.translationValues(center.dx, center.dy, 0);
    final scaleM = Matrix4.diagonal3Values(scaleDelta, scaleDelta, 1.0);
    final back = Matrix4.translationValues(-center.dx, -center.dy, 0);
    _tc.value = toCenter * scaleM * back * matrix;
    _currentScale = clamped;
  }

  void _zoomIn() => _applyZoom(_tc.value.getMaxScaleOnAxis() + 0.5);
  void _zoomOut() => _applyZoom(_tc.value.getMaxScaleOnAxis() - 0.5);

  void _resetZoom() {
    _currentScale = 1.0;
    _tc.value = Matrix4.identity();
  }

  void _toggleZoom() {
    if (_tc.value.getMaxScaleOnAxis() > 1.0) {
      _resetZoom();
    } else {
      _applyZoom(2.0);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _annotMode) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.equal:
        _zoomIn();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
        _zoomOut();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        _resetZoom();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void enterAnnotationMode() async {
    // 移动端：直接进入标注模式，工具栏接管配置
    if (AnnotationToolbar.isSupported) {
      setState(() => _annotMode = true);
      return;
    }
    // 桌面端：保留 Dialog 流程
    final type = await showDialog<AnnotationType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择标注类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.freeform),
            child: const ListTile(leading: Icon(Icons.brush, color: Color(0xFFFF9800)), title: Text('自由画笔')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.note),
            child: const ListTile(leading: Icon(Icons.notes, color: Color(0xFF4CAF50)), title: Text('批注')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.highlight),
            child: const ListTile(leading: Icon(Icons.format_paint, color: Color(0xFFFFEB3B)), title: Text('高亮（桌面）')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.underline),
            child: const ListTile(leading: Icon(Icons.format_underlined, color: Color(0xFF2196F3)), title: Text('划线（桌面）')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.eraser),
            child: const ListTile(leading: Icon(Icons.auto_fix_high, color: Colors.grey), title: Text('橡皮擦')),
          ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    final isFreeform = type == AnnotationType.freeform;
    if (type == AnnotationType.eraser) {
      // 橡皮擦跳过颜色选择器，直接使用白色粗笔
      setState(() {
        _annotMode = true;
        _tool = type;
        _color = Colors.white;
        _opacity = 1.0;
        _thickness = 20;
      });
      return;
    }
    final style = await AnnotationColorPicker.show(
      context,
      showBrushPicker: isFreeform,
    );
    if (style == null || !mounted) return;
    setState(() {
      _annotMode = true;
      _tool = type;
      _color = style.color;
      _opacity = style.opacity;
      _thickness = style.thickness;
      if (isFreeform) _brushType = style.brushType;
    });
  }

  void _exit() => setState(() => _annotMode = false);

  void _handleToolbarChange(AnnotationToolConfig cfg) {
    setState(() {
      _tool = cfg.tool;
      _color = cfg.color;
      _opacity = cfg.opacity;
      _thickness = cfg.thickness;
      if (cfg.tool == AnnotationType.freeform) _brushType = cfg.brushType;
      _allowFingerDraw = cfg.allowFingerDraw;
    });
  }

  Future<void> _handleUndo() async {
    await AnnotationService.popLast(widget.filePath);
    if (mounted) setState(() => _annotRefreshCounter++);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: [
          // 内容层
          AnnotationLayer(
            filePath: widget.filePath,
            pageIndex: 0,
            enabled: _annotMode,
            tool: _tool,
            color: _color,
            opacity: _opacity,
            thickness: _thickness,
            brushType: _brushType,
            allowFingerDraw: _allowFingerDraw,
            refreshCounter: _annotRefreshCounter,
            onClose: _exit,
            child: InteractiveViewer(
              transformationController: _tc,
              panEnabled: !_annotMode,
              scaleEnabled: !_annotMode,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.5,
              maxScale: 5.0,
              onInteractionEnd: (details) {
                final matrix = _tc.value;
                _currentScale = matrix.getMaxScaleOnAxis();
              },
              child: GestureDetector(
                onDoubleTap: _toggleZoom,
                child: Center(
                  child: Image.file(
                    File(widget.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('无法加载图片', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 标注工具栏（移动端）/ 指示器（桌面端）
          if (_annotMode && AnnotationToolbar.isSupported)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnnotationToolbar(
                initialConfig: AnnotationToolConfig(
                  tool: _tool,
                  brushType: _brushType,
                  color: _color,
                  opacity: _opacity,
                  thickness: _thickness,
                  allowFingerDraw: _allowFingerDraw,
                ),
                onChanged: _handleToolbarChange,
                onUndo: _handleUndo,
                onExit: _exit,
              ),
            ),
          if (_annotMode && !AnnotationToolbar.isSupported)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildIndicator()),

          // 缩放按钮
          Positioned(
            right: 16,
            bottom: _annotMode
                ? (AnnotationToolbar.isSupported ? 110 : 60)
                : 16,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ZBtn(Icons.add, _zoomIn, '放大 (+)'),
              const SizedBox(height: 4),
              _ZPct(_currentScale, _resetZoom),
              const SizedBox(height: 4),
              _ZBtn(Icons.remove, _zoomOut, '缩小 (-)'),
              const SizedBox(height: 8),
              _ZBtn(_annotMode ? Icons.edit_off : Icons.edit,
                  _annotMode ? _exit : enterAnnotationMode,
                  _annotMode ? '退出标注' : '标注模式'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    String label;
    if (_tool == AnnotationType.freeform) {
      label = ['铅笔', '画笔', '水彩笔'][_brushType.clamp(0, 2)];
    } else if (_tool == AnnotationType.highlight) {
      label = '高亮';
    } else if (_tool == AnnotationType.underline) {
      label = '划线';
    } else if (_tool == AnnotationType.eraser) {
      label = '橡皮擦';
    } else {
      label = '批注';
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black87,
        child: Row(children: [
          Container(width: 14, height: 14,
            decoration: BoxDecoration(color: _color.withValues(alpha: _opacity),
                borderRadius: BorderRadius.circular(3), border: Border.all(color: _color))),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          TextButton(onPressed: _exit, child: const Text('退出', style: TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }
}

class _ZPct extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;
  const _ZPct(this.scale, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4, borderRadius: BorderRadius.circular(20), color: AppTheme.surface,
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap,
        child: Tooltip(message: '双击切换 / 点击重置',
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('${(scale * 100).round()}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryDark))))),
    );
  }
}

class _ZBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  const _ZBtn(this.icon, this.onPressed, this.tooltip);
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4, shape: const CircleBorder(), color: AppTheme.primaryColor,
      child: InkWell(customBorder: const CircleBorder(), onTap: onPressed,
        child: Tooltip(message: tooltip,
          child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: Colors.white, size: 22)))),
    );
  }
}
