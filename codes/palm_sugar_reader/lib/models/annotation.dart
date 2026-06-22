import 'package:flutter/material.dart';

/// 标注类型
enum AnnotationType { highlight, underline, note, freeform, eraser }

/// 画笔类型（仅 freeform 模式使用）
enum BrushType { pencil, pen, watercolor }

/// 标注数据模型 — 坐标全部为相对于页面宽高的 0~1 比例
class Annotation {
  final String id;
  final String filePath;
  final AnnotationType type;
  final int pageIndex;  // 页码（0-based）
  final double x;       // 矩形左边界 / 页面宽度 (0.0 ~ 1.0)
  final double y;       // 矩形上边界 / 页面高度 (0.0 ~ 1.0)
  final double width;   // 矩形宽度 / 页面宽度 (0.0 ~ 1.0)
  final double height;  // 矩形高度 / 页面高度 (0.0 ~ 1.0)
  final int colorValue; // Color.toARGB32()
  final double opacity;
  final double thickness; // 像素，标注线/矩形的固定高度
  final String? noteText; // 批注文字（仅 note 类型）
  final List<double>? points; // 自由画笔路径（仅 freeform 类型）— 归一化坐标 [x1,y1, x2,y2, ...]
  final int brushType; // 画笔类型 0=pencil 1=pen 2=watercolor（仅 freeform 类型）
  final DateTime createdAt;

  Annotation({
    required this.id,
    required this.filePath,
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.noteText,
    this.points,
    this.brushType = 0,
    required this.thickness,
    required this.colorValue,
    this.opacity = 0.4,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  /// 从绝对像素坐标创建（自动归一化）
  factory Annotation.fromPixelRect({
    required String id,
    required String filePath,
    required AnnotationType type,
    required int pageIndex,
    required double pageWidth,
    required double pageHeight,
    required double pxX,
    required double pxY,
    required double pxWidth,
    required double pxHeight,
    String? noteText,
    required int colorValue,
    required double thickness,
    double opacity = 0.4,
  }) {
    return Annotation(
      id: id,
      filePath: filePath,
      type: type,
      pageIndex: pageIndex,
      x: (pxX / pageWidth).clamp(0.0, 1.0),
      y: (pxY / pageHeight).clamp(0.0, 1.0),
      width: (pxWidth / pageWidth).clamp(0.0, 1.0),
      height: (pxHeight / pageHeight).clamp(0.0, 1.0),
      colorValue: colorValue,
      opacity: opacity,
      thickness: thickness,
      noteText: noteText,
    );
  }

  /// 转为屏幕像素矩形
  Rect toPixelRect(double pageWidth, double pageHeight) {
    return Rect.fromLTWH(
      x * pageWidth,
      y * pageHeight,
      width * pageWidth,
      height * pageHeight,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'type': type.name,
        'pageIndex': pageIndex,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'colorValue': colorValue,
        'opacity': opacity,
        'thickness': thickness,
        if (noteText != null) 'noteText': noteText,
        if (points != null) 'points': points,
        if (brushType != 0) 'brushType': brushType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Annotation.fromJson(Map<String, dynamic> json) {
    final pts = json['points'] as List<dynamic>?;
    return Annotation(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      type: AnnotationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AnnotationType.highlight,
      ),
      pageIndex: json['pageIndex'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      colorValue: json['colorValue'] as int,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.4,
      thickness: (json['thickness'] as num?)?.toDouble() ?? 8,
      noteText: json['noteText'] as String?,
      points: pts?.map((e) => (e as num).toDouble()).toList(),
      brushType: (json['brushType'] as int?) ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
