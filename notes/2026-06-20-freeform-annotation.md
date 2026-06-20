---
date: 2026-06-20
tags:
  - learning
  - flutter
  - annotation
  - canvas
---

# 自由画笔标注系统

> 为平板端实现的自由手写标注模式，替代桌面端的高亮/划线。

## 架构

### 数据模型

`Annotation` 新增字段：
- `List<double>? points` — 归一化坐标列表 `[x1,y1, x2,y2, ...]`，每点相对页面 0~1
- `int brushType` — 0=铅笔, 1=画笔, 2=水彩笔

新增枚举 `AnnotationType.freeform` 和 `BrushType`。

### 事件处理

`AnnotationLayer` 根据 `tool` 分三种事件模式：
1. **freeform**: `onPointerDown` 起笔 → `onPointerMove` 收集点 → `onPointerUp` 归一并保存
2. **note**: `onTap` 放置便签 / `onPointerDown` 拖动
3. **highlight/underline**: 拖拽矩形（保留桌面端）

### 渲染

自由画笔用 `Path.quadraticBezierTo` 做贝塞尔平滑：
- 两点 → 直线
- 多点 → 每段取中点做二次贝塞尔，最后一点直线收尾

笔刷差异只是 `Paint` 配置：
```dart
// 铅笔: 细 + 半透明
paint..strokeWidth = thickness * 0.4..color.withAlpha(opacity * 0.7)
// 水彩: 粗 + 模糊
paint..strokeWidth = thickness..maskFilter = MaskFilter.blur(normal, 3)
// 画笔: 中等 + 圆角
paint..strokeWidth = thickness..strokeCap = round
```

### ColorPicker 扩展

- 预置色加黑色 `Color(0xFF000000)`
- `showBrushPicker` 参数：为 true 时显示铅笔/画笔/水彩笔三选一
- 返回值新增 `brushType` 字段

### 标注入口

全部三种阅读器（PDF/EPUB/图片）统一弹窗顺序：自由画笔 > 批注 > 高亮(桌面) > 划线(桌面)
