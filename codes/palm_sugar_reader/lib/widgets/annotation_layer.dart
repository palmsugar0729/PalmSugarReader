import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';

/// 标注图层 —— 盖在内容上的透明画布
///
/// - 高亮/划线：拖拽画矩形（桌面端保留）
/// - 自由画笔：手写路径，支持铅笔/画笔/水彩笔
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
  final int brushType; // 0=pencil 1=pen 2=watercolor
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
    this.brushType = 0,
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

  // ── 自由画笔 ──
  final List<Offset> _currentStroke = [];

  bool get _isFreeform => widget.tool == AnnotationType.freeform;

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
      final hit = _hitTestNote(e.localPosition);
      if (hit != null) {
        setState(() { _dragging = hit; _startPoint = e.localPosition; });
      }
    } else if (_isFreeform) {
      // 自由画笔：开始新一笔
      setState(() {
        _drawing = true;
        _currentStroke.clear();
        _currentStroke.add(e.localPosition);
      });
    } else {
      // 高亮/划线：拖拽矩形
      setState(() { _drawing = true; _startPoint = e.localPosition; _currentPoint = e.localPosition; });
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (_dragging != null) return;
    if (!_drawing) return;
    if (_isFreeform) {
      setState(() => _currentStroke.add(e.localPosition));
    } else {
      setState(() => _currentPoint = e.localPosition);
    }
  }

  void _onUp(PointerUpEvent e) async {
    // ── 拖动便签结束 ──
    if (_dragging != null) {
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

    if (!_drawing) return;

    // ── 自由画笔结束 → 保存 ──
    if (_isFreeform) {
      setState(() => _drawing = false);
      if (_currentStroke.length < 2) {
        _currentStroke.clear();
        return;
      }
      // 归一化坐标
      final pw = _pageSize.width;
      final ph = _pageSize.height;
      final pts = <double>[];
      for (final p in _currentStroke) {
        pts.addAll([(p.dx / pw).clamp(0.0, 1.0), (p.dy / ph).clamp(0.0, 1.0)]);
      }
      final ann = Annotation(
        id: AnnotationService.generateId(),
        filePath: widget.filePath,
        type: AnnotationType.freeform,
        pageIndex: widget.pageIndex,
        x: 0, y: 0, width: 0, height: 0,
        thickness: widget.thickness,
        colorValue: widget.color.toARGB32(),
        opacity: widget.opacity,
        points: pts,
        brushType: widget.brushType,
      );
      await AnnotationService.add(ann);
      _annotations.add(ann);
      _currentStroke.clear();
      if (mounted) setState(() {});
      return;
    }

    // ── 高亮/划线结束 → 保存 ──
    if (_startPoint == null || _currentPoint == null) return;
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
                if (_drawing) _buildPreview(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    if (_isFreeform) {
      // 自由画笔预览
      return CustomPaint(
        size: _pageSize,
        painter: _FreeformPreviewPainter(
          points: List.from(_currentStroke),
          color: widget.color,
          opacity: widget.opacity,
          thickness: widget.thickness,
          brushType: widget.brushType,
        ),
      );
    }
    // 高亮/划线预览
    if (_startPoint != null && _currentPoint != null) {
      return CustomPaint(
        size: _pageSize,
        painter: _PrevPainter(
          rect: Rect.fromLTWH(
            _startPoint!.dx < _currentPoint!.dx ? _startPoint!.dx : _currentPoint!.dx,
            _startPoint!.dy,
            (_startPoint!.dx - _currentPoint!.dx).abs(),
            widget.thickness,
          ),
          color: widget.color,
          opacity: widget.opacity,
          tool: widget.tool,
          thickness: widget.thickness,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── 完整标注渲染器 ──

class _AnnPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Size pageSize;
  _AnnPainter({required this.annotations, required this.pageSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in annotations) {
      if (ann.type == AnnotationType.freeform) {
        _drawFreeform(canvas, ann);
      } else if (ann.type == AnnotationType.highlight || ann.type == AnnotationType.underline) {
        _drawRect(canvas, ann);
      } else if (ann.type == AnnotationType.note) {
        _drawNote(canvas, ann);
      }
    }
  }

  void _drawFreeform(Canvas canvas, Annotation ann) {
    final pts = ann.points;
    if (pts == null || pts.length < 4) return;
    final pw = pageSize.width;
    final ph = pageSize.height;

    final path = ui.Path();
    path.moveTo(pts[0] * pw, pts[1] * ph);

    if (pts.length == 4) {
      // 只有两个点 → 直线
      path.lineTo(pts[2] * pw, pts[3] * ph);
    } else {
      // 多个点 → 贝塞尔平滑
      for (int i = 2; i < pts.length - 2; i += 2) {
        final x1 = pts[i] * pw;
        final y1 = pts[i + 1] * ph;
        final x2 = pts[i + 2] * pw;
        final y2 = pts[i + 3] * ph;
        final midX = (x1 + x2) / 2;
        final midY = (y1 + y2) / 2;
        path.quadraticBezierTo(x1, y1, midX, midY);
      }
      // 最后一个点
      path.lineTo(pts[pts.length - 2] * pw, pts[pts.length - 1] * ph);
    }

    final paint = _brushPaint(ann);
    canvas.drawPath(path, paint);
  }

  Paint _brushPaint(Annotation ann) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (ann.brushType) {
      case 0: // pencil
        paint
          ..color = ann.color.withValues(alpha: ann.opacity * 0.7)
          ..strokeWidth = (ann.thickness * 0.4).clamp(1.5, 6);
        break;
      case 2: // watercolor
        paint
          ..color = ann.color.withValues(alpha: ann.opacity * 0.3)
          ..strokeWidth = ann.thickness.clamp(10, 40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        break;
      default: // pen
        paint
          ..color = ann.color.withValues(alpha: ann.opacity)
          ..strokeWidth = ann.thickness.clamp(3, 20);
        break;
    }
    return paint;
  }

  void _drawRect(Canvas canvas, Annotation ann) {
    final rect = ann.toPixelRect(pageSize.width, pageSize.height);
    final paint = Paint()..color = ann.color.withValues(alpha: ann.opacity)..style = PaintingStyle.fill;

    if (ann.type == AnnotationType.highlight) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2), paint..color = ann.color);
    }
  }

  void _drawNote(Canvas canvas, Annotation ann) {
    final rect = ann.toPixelRect(pageSize.width, pageSize.height);
    final r = Rect.fromLTWH(rect.left, rect.top, 24, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()..color = ann.color.withValues(alpha: 0.85),
    );
    final tp = TextPainter(
      text: TextSpan(text: 'N', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r.left + (24 - tp.width) / 2, r.top + (24 - tp.height) / 2));
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

  @override
  bool shouldRepaint(covariant _AnnPainter old) => annotations != old.annotations || pageSize != old.pageSize;
}

// ── 自由画笔预览 ──

class _FreeformPreviewPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double opacity;
  final double thickness;
  final int brushType;

  _FreeformPreviewPainter({
    required this.points,
    required this.color,
    required this.opacity,
    required this.thickness,
    required this.brushType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = ui.Path();
    path.moveTo(points[0].dx, points[0].dy);

    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final mid = Offset((points[i].dx + points[i + 1].dx) / 2, (points[i].dy + points[i + 1].dy) / 2);
        path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (brushType) {
      case 0: // pencil
        paint
          ..color = color.withValues(alpha: opacity * 0.7)
          ..strokeWidth = (thickness * 0.4).clamp(1.5, 6);
        break;
      case 2: // watercolor
        paint
          ..color = color.withValues(alpha: opacity * 0.3)
          ..strokeWidth = thickness.clamp(10, 40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        break;
      default: // pen
        paint
          ..color = color.withValues(alpha: opacity)
          ..strokeWidth = thickness.clamp(3, 20);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FreeformPreviewPainter old) => points != old.points || color != old.color;
}

// ── 高亮/划线预览 ──

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
