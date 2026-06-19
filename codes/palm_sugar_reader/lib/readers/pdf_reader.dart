import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/annotation.dart';
import '../theme.dart';
import '../widgets/annotation_layer.dart';
import '../widgets/color_picker.dart';

class PdfReader extends StatefulWidget {
  final String filePath;
  const PdfReader({super.key, required this.filePath});
  @override
  State<PdfReader> createState() => PdfReaderState();
}

class PdfReaderState extends State<PdfReader> {
  final PdfViewerController _ctrl = PdfViewerController();
  final FocusNode _focusNode = FocusNode();
  double _zoom = 1.0;
  bool _showSlider = false;
  int _currentPage = 1;
  int _pageCount = 1;
  bool _annotMode = false;
  AnnotationType _tool = AnnotationType.highlight;
  Color _color = const Color(0xFFFFEB3B);
  double _opacity = 0.4;
  double _thickness = 8;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final z = _ctrl.currentZoom;
      if (z != _zoom) setState(() => _zoom = z);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _zoomIn() => _ctrl.zoomUp(duration: const Duration(milliseconds: 150));
  void _zoomOut() => _ctrl.zoomDown(duration: const Duration(milliseconds: 150));
  void _setZoom(double z) => _ctrl.setZoom(Offset.zero, z, duration: const Duration(milliseconds: 150));

  void _handleSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final k = HardwareKeyboard.instance.logicalKeysPressed;
      final ctrl = k.contains(LogicalKeyboardKey.controlLeft) || k.contains(LogicalKeyboardKey.controlRight);
      if (ctrl) {
        if (e.scrollDelta.dy < 0) _zoomIn();
        else if (e.scrollDelta.dy > 0) _zoomOut();
      }
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
      _ctrl.goToPage(pageNumber: (_currentPage - (key == LogicalKeyboardKey.pageUp ? 10 : 1)).clamp(1, _pageCount));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.pageDown) {
      _ctrl.goToPage(pageNumber: (_currentPage + (key == LogicalKeyboardKey.pageDown ? 10 : 1)).clamp(1, _pageCount));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _ctrl.goToPage(pageNumber: 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _ctrl.goToPage(pageNumber: _pageCount);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  void _exitAnnotMode() => setState(() => _annotMode = false);

  List<Widget> _pageOverlaysBuilder(BuildContext context, Rect pageRect, PdfPage page) {
    return [
      Positioned.fill(
        child: AnnotationLayer(
          filePath: widget.filePath,
          pageIndex: page.pageNumber - 1,
          enabled: _annotMode,
          tool: _tool,
          color: _color,
          opacity: _opacity,
          thickness: _thickness,
          onClose: _exitAnnotMode,
          child: const SizedBox.expand(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: [
          // PDF 视图
          Listener(
            onPointerSignal: _handleSignal,
            child: PdfViewer.file(
              widget.filePath,
              controller: _ctrl,
              params: PdfViewerParams(
                backgroundColor: const Color(0xFFE0E0E0),
                enableTextSelection: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                pageOverlaysBuilder: _pageOverlaysBuilder,
                margin: 8,
                onPageChanged: (p) => setState(() => _currentPage = p ?? _currentPage),
                onViewerReady: (document, controller) {
                  setState(() => _pageCount = document.pages.length);
                },
              ),
            ),
          ),

          // 标注指示器
          if (_annotMode)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildIndicator()),

          // 缩放按钮
          Positioned(
            right: 16, bottom: _annotMode ? 60 : 16,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ZoomBtn(Icons.add, _zoomIn, '放大'),
              const SizedBox(height: 4),
              _ZoomPct(_zoom, () => setState(() => _showSlider = !_showSlider)),
              const SizedBox(height: 4),
              _ZoomBtn(Icons.remove, _zoomOut, '缩小'),
              const SizedBox(height: 8),
              _ZoomBtn(_annotMode ? Icons.edit_off : Icons.edit,
                  _annotMode ? _exitAnnotMode : enterAnnotationMode,
                  _annotMode ? '退出标注' : '标注模式'),
            ]),
          ),

          // 缩放滑条
          if (_showSlider)
            Positioned(left: 16, right: 80, bottom: 16,
              child: _ZoomSlider(_zoom, _setZoom, () => setState(() => _showSlider = false))),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.surface, boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, -2)),
        ]),
        child: Row(children: [
          Container(width: 16, height: 16,
            decoration: BoxDecoration(color: _color.withValues(alpha: _opacity),
                borderRadius: BorderRadius.circular(3), border: Border.all(color: _color))),
          const SizedBox(width: 8),
          Text(_tool == AnnotationType.highlight ? '高亮模式' : _tool == AnnotationType.underline ? '划线模式' : '批注模式',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(_tool == AnnotationType.note ? '点击页面放置便签' : '拖拽鼠标画标注',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const Spacer(),
          TextButton(onPressed: _exitAnnotMode, child: const Text('退出')),
        ]),
      ),
    );
  }
}

// ── 缩放 UI ──

class _ZoomPct extends StatelessWidget {
  final double zoom;
  final VoidCallback onTap;
  const _ZoomPct(this.zoom, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4, borderRadius: BorderRadius.circular(20), color: AppTheme.surface,
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap,
        child: Tooltip(message: '展开滑条',
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('${(zoom * 100).round()}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryDark))))),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  final double zoom;
  final ValueChanged<double> onChanged;
  final VoidCallback onClose;
  const _ZoomSlider(this.zoom, this.onChanged, this.onClose);
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6, borderRadius: BorderRadius.circular(12), color: AppTheme.surface,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _MiniBtn(Icons.remove, () => onChanged((zoom - 0.1).clamp(0.25, 5.0))),
          Expanded(child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: AppTheme.primaryColor, inactiveTrackColor: AppTheme.primaryLight.withAlpha(100),
              thumbColor: AppTheme.primaryDark, overlayColor: AppTheme.primaryColor.withAlpha(40)),
            child: Slider(value: zoom.clamp(0.25, 5.0), min: 0.25, max: 5.0, divisions: 19, onChanged: onChanged))),
          _MiniBtn(Icons.add, () => onChanged((zoom + 0.1).clamp(0.25, 5.0))),
          const SizedBox(width: 4), _MiniBtn(Icons.close, onClose),
        ])),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  const _ZoomBtn(this.icon, this.onPressed, this.tooltip);
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

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 18, color: AppTheme.primaryDark)));
  }
}
