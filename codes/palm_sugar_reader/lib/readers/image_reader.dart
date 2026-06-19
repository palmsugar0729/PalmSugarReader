import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/annotation.dart';
import '../theme.dart';
import '../widgets/annotation_layer.dart';
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
  AnnotationType _tool = AnnotationType.highlight;
  Color _color = const Color(0xFFFFEB3B);
  double _opacity = 0.4;
  double _thickness = 8;

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
    final type = await showDialog<AnnotationType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择标注类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.highlight),
            child: const ListTile(leading: Icon(Icons.format_paint, color: Color(0xFFFFEB3B)), title: Text('高亮')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.underline),
            child: const ListTile(leading: Icon(Icons.format_underlined, color: Color(0xFF2196F3)), title: Text('划线')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.note),
            child: const ListTile(leading: Icon(Icons.notes, color: Color(0xFF4CAF50)), title: Text('批注')),
          ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    final style = await AnnotationColorPicker.show(context);
    if (style == null || !mounted) return;
    setState(() {
      _annotMode = true;
      _tool = type;
      _color = style.color;
      _opacity = style.opacity;
      _thickness = style.thickness;
    });
  }

  void _exit() => setState(() => _annotMode = false);

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

          // 缩放按钮
          Positioned(
            right: 16, bottom: _annotMode ? 60 : 16,
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

          // 标注指示器
          if (_annotMode)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildIndicator()),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black87,
        child: Row(children: [
          Container(width: 14, height: 14,
            decoration: BoxDecoration(color: _color.withValues(alpha: _opacity),
                borderRadius: BorderRadius.circular(3), border: Border.all(color: _color))),
          const SizedBox(width: 8),
          Text(_tool == AnnotationType.highlight ? '高亮模式' : _tool == AnnotationType.underline ? '划线模式' : '批注模式',
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
