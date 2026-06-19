import 'package:flutter/material.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';

/// 标注图层 —— 盖在内容上的透明画布
///
/// - 高亮/划线：拖拽画矩形，固定高度(=thickness)
/// - 批注：点击放置便签，可拖动移动，点击查看编辑
class AnnotationLayer extends StatefulWidget {
  final Widget child;
  final String filePath;
  final int pageIndex;
  final bool enabled;
  final AnnotationType tool;
  final Color color;
  final double opacity;
  final double thickness;
  final VoidCallback? onClose;

  const AnnotationLayer({
    super.key,
    required this.child,
    required this.filePath,
    required this.pageIndex,
    this.enabled = false,
    this.tool = AnnotationType.highlight,
    this.color = const Color(0xFFFFEB3B),
    this.opacity = 0.4,
    this.thickness = 8,
    this.onClose,
  });

  @override
  State<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends State<AnnotationLayer> {
  List<Annotation> _annotations = [];
  bool _drawing = false;
  Offset? _startPoint;
  Offset? _currentPoint;
  Size _pageSize = Size.zero;
  Annotation? _dragging;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnnotationLayer old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath || old.pageIndex != widget.pageIndex) {
      _annotations = [];
      _load();
    }
  }

  Future<void> _load() async {
    if (!AnnotationService.enabled) return;
    final all = await AnnotationService.loadForFile(widget.filePath);
    if (mounted) setState(() => _annotations = all.where((a) => a.pageIndex == widget.pageIndex).toList());
  }

  // ── 命中检测 ──

  Annotation? _hitTestNote(Offset pos) {
    for (final a in _annotations.reversed) {
      if (a.type != AnnotationType.note) continue;
      final r = a.toPixelRect(_pageSize.width, _pageSize.height);
      if (r.contains(pos)) return a;
    }
    return null;
  }

  // ── 指针事件 ──

  void _onDown(PointerDownEvent e) {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _pageSize = box.size;
    if (_pageSize.isEmpty) return;

    if (widget.tool == AnnotationType.note) {
      // 便签模式：点击/拖动已有
      final hit = _hitTestNote(e.localPosition);
      if (hit != null) {
        setState(() { _dragging = hit; _startPoint = e.localPosition; });
      }
    } else {
      setState(() { _drawing = true; _startPoint = e.localPosition; _currentPoint = e.localPosition; });
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (_dragging != null) return; // 拖动中
    if (!_drawing) return;
    setState(() => _currentPoint = e.localPosition);
  }

  void _onUp(PointerUpEvent e) async {
    if (_dragging != null) {
      // 结束拖动 → 更新位置
      if (_startPoint != null) {
        final dx = e.localPosition.dx - _startPoint!.dx;
        final dy = e.localPosition.dy - _startPoint!.dy;
        if (dx.abs() > 2 || dy.abs() > 2) {
          final ann = _dragging!;
          final pw = _pageSize.width;
          final ph = _pageSize.height;
          final nx = (ann.x * pw + dx) / pw;
          final ny = (ann.y * ph + dy) / ph;
          final updated = Annotation(
            id: ann.id, filePath: ann.filePath, type: ann.type,
            pageIndex: ann.pageIndex, x: nx.clamp(0, 1), y: ny.clamp(0, 1),
            width: ann.width, height: ann.height, thickness: ann.thickness,
            colorValue: ann.colorValue, opacity: ann.opacity, noteText: ann.noteText,
          );
          _annotations.remove(ann);
          _annotations.add(updated);
          await AnnotationService.add(updated);
        }
      }
      setState(() { _dragging = null; _startPoint = null; });
      return;
    }

    if (!_drawing || _startPoint == null || _currentPoint == null) return;
    setState(() => _drawing = false);

    final raw = _makeRect(_startPoint!, _currentPoint!);
    if (raw.width < 3) return;

    final rect = Rect.fromLTWH(raw.left, raw.top, raw.width, widget.thickness);
    final ann = Annotation.fromPixelRect(
      id: AnnotationService.generateId(), filePath: widget.filePath,
      type: widget.tool, pageIndex: widget.pageIndex,
      pageWidth: _pageSize.width, pageHeight: _pageSize.height,
      pxX: rect.left, pxY: rect.top, pxWidth: rect.width, pxHeight: rect.height,
      colorValue: widget.color.toARGB32(), opacity: widget.opacity, thickness: widget.thickness,
    );
    await AnnotationService.add(ann);
    _annotations.add(ann);
    _startPoint = null;
    _currentPoint = null;
    if (mounted) setState(() {});
  }

  void _onTap(TapUpDetails d) async {
    if (!widget.enabled || widget.tool != AnnotationType.note) return;
    final hit = _hitTestNote(d.localPosition);
    if (hit != null) {
      _showNoteDialog(hit);
      return;
    }
    _placeNote(d.localPosition);
  }

  Future<void> _placeNote(Offset pos) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加批注'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 4,
          decoration: const InputDecoration(hintText: '输入批注内容...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.isEmpty ? null : ctrl.text), child: const Text('保存')),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final pw = _pageSize.width;
    final ph = _pageSize.height;
    final ann = Annotation(
      id: AnnotationService.generateId(), filePath: widget.filePath,
      type: AnnotationType.note, pageIndex: widget.pageIndex,
      x: (pos.dx - 16) / pw, y: (pos.dy - 16) / ph, width: 32 / pw, height: 32 / ph,
      thickness: 32, colorValue: widget.color.toARGB32(), opacity: widget.opacity,
      noteText: text,
    );
    await AnnotationService.add(ann);
    _annotations.add(ann);
    setState(() {});
  }

  void _showNoteDialog(Annotation ann) async {
    final ctrl = TextEditingController(text: ann.noteText ?? '');
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批注'),
        content: TextField(controller: ctrl, maxLines: 4,
          decoration: const InputDecoration(hintText: '批注内容...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('删除', style: TextStyle(color: Colors.red))),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('保存')),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'delete') {
      await AnnotationService.remove(widget.filePath, ann.id);
      setState(() => _annotations.remove(ann));
    } else if (action != ann.noteText) {
      final updated = Annotation(
        id: ann.id, filePath: ann.filePath, type: ann.type, pageIndex: ann.pageIndex,
        x: ann.x, y: ann.y, width: ann.width, height: ann.height, thickness: ann.thickness,
        colorValue: ann.colorValue, opacity: ann.opacity, noteText: action,
      );
      _annotations.remove(ann);
      _annotations.add(updated);
      await AnnotationService.add(updated);
      setState(() {});
    }
  }

  Rect _makeRect(Offset a, Offset b) {
    return Rect.fromLTRB(
      a.dx < b.dx ? a.dx : b.dx, a.dy < b.dy ? a.dy : b.dy,
      a.dx > b.dx ? a.dx : b.dx, a.dy > b.dy ? a.dy : b.dy,
    );
  }

  // ── 渲染 ──

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        _pageSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          child: GestureDetector(
            onTapUp: _onTap,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                widget.child,
                CustomPaint(size: _pageSize, painter: _AnnPainter(annotations: _annotations, pageSize: _pageSize)),
                if (_drawing && _startPoint != null && _currentPoint != null && widget.tool != AnnotationType.note)
                  CustomPaint(size: _pageSize, painter: _PrevPainter(
                    rect: Rect.fromLTWH(
                      _startPoint!.dx < _currentPoint!.dx ? _startPoint!.dx : _currentPoint!.dx,
                      _startPoint!.dy,
                      (_startPoint!.dx - _currentPoint!.dx).abs(),
                      widget.thickness,
                    ),
                    color: widget.color, opacity: widget.opacity, tool: widget.tool, thickness: widget.thickness)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnnPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Size pageSize;
  _AnnPainter({required this.annotations, required this.pageSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in annotations) {
      final rect = ann.toPixelRect(pageSize.width, pageSize.height);
      final paint = Paint()..color = ann.color.withValues(alpha: ann.opacity)..style = PaintingStyle.fill;

      if (ann.type == AnnotationType.highlight) {
        canvas.drawRect(rect, paint);
      } else if (ann.type == AnnotationType.underline) {
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2), paint..color = ann.color);
      } else if (ann.type == AnnotationType.note) {
        // 便签标记：小色块 + 图标
        final r = Rect.fromLTWH(rect.left, rect.top, 24, 24);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), paint..color = ann.color.withValues(alpha: 0.85));
        final tp = TextPainter(
          text: TextSpan(text: 'N', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(r.left + (24 - tp.width) / 2, r.top + (24 - tp.height) / 2));
        // 显示批注文字摘要
        if (ann.noteText != null && ann.noteText!.isNotEmpty) {
          final preview = ann.noteText!.length > 12 ? '${ann.noteText!.substring(0, 12)}...' : ann.noteText!;
          final np = TextPainter(
            text: TextSpan(text: preview, style: TextStyle(color: ann.color, fontSize: 10)),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(r.right + 4, r.top, np.width + 8, 20), const Radius.circular(4)),
            Paint()..color = ann.color.withValues(alpha: 0.15),
          );
          np.paint(canvas, Offset(r.right + 8, r.top + 3));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnnPainter old) => annotations != old.annotations || pageSize != old.pageSize;
}

class _PrevPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final double opacity;
  final double thickness;
  final AnnotationType tool;
  _PrevPainter({required this.rect, required this.color, required this.opacity, required this.thickness, required this.tool});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity)..style = PaintingStyle.fill;
    if (tool == AnnotationType.highlight) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2), paint..color = color);
    }
    paint..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _PrevPainter old) => rect != old.rect || color != old.color;
}
