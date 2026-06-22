---
date: 2026-06-21
tags: [meeting, prd, flutter, annotation, handwriting, palm-rejection, toolbar]
project: PalmSugarReader
aliases: ["平板手写工具栏重构讨论", "2026-06-21 标注UX讨论"]
---

# 平板手写标注工具栏重构 + 防误触 讨论记录

> **关联**：[[PRD]] · [[implementation-plan-2.0]] · [[discussion-2026-06-19]]

## 一、讨论要点

### 1. 防误触 — 好做

Flutter 的 `PointerEvent.kind` 可以区分：
- `PointerDeviceKind.stylus` — 笔尖
- `PointerDeviceKind.touch` — 手指/手掌

在手写模式下只响应 `stylus`，手掌碰到屏幕自然被忽略。GoodNotes 也是这个做法。

**改动量**：AnnotationLayer 三个方法各加一行过滤，<10 行。

### 2. 平板端工具栏 — GoodNotes 模式

**现状**：标注入口需要两个串行 Dialog（选工具 → 颜色/粗细/画笔），中途改设置必须退出重进。

**目标**：常驻底部浮动工具栏，两行布局：
- 工具行：[笔][画笔][水彩][荧光笔][橡皮][便签] + [↩撤销] [✕退出]
- 颜色/粗细行：[⚫🟡🟢🔵🔴🟠] + [S][M][L] + [⚙更多]

可折叠为 44×44 浮动圆钮。所有切换即时生效，无确认步骤。

### 3. 产品定位 — PotPlayer 类比

- 轻量、启动快、格式通吃
- 功能深藏不臃肿 — 默认界面干净，需要时一个手势唤出
- MVP 优先，先出简单能用的，看反馈再迭代

## 二、技术决策

| # | 决策点 | 选项 | 选择 | 理由 |
|---|--------|------|------|------|
| 1 | 桌面端是否也用新工具栏 | 统一用 / 桌面保留Dialog | 桌面保留Dialog | 鼠标操作Dialog不是痛点，减少桌面端改动风险 |
| 2 | 橡皮擦实现 | BlendMode.clear / 白色粗笔 | 白色粗笔 | 避免PDF页面上的Canvas兼容问题，MVP够用 |
| 3 | 三个Reader的重复代码 | 抽取mixin / 各自改 | 各自改 | 避免过度抽象，三个Reader各有差异不宜强统 |
| 4 | 是否新建AnnotationToolConfig类 | 新建 / 用Map传参 | 新建 | 类型安全，减少参数传递错误 |

## 三、实现步骤

1. AnnotationToolbar 骨架（新建 widget）
2. 防误触（AnnotationLayer stylus 过滤）
3. 橡皮擦 + 撤销（Annotation 模型扩展 + AnnotationService.popLast）
4. PDF Reader 集成（第一个完整验证）
5. Image Reader 集成（InteractiveViewer 协调）
6. EPUB Reader 集成（修复缺失退出按钮）
7. 桌面端兼容确认

## 四、下一步

- [ ] 用户审阅计划文档
- [ ] 确认后开始 Step 1：AnnotationToolbar 骨架
