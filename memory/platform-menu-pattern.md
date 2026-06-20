---
name: platform-menu-pattern
description: 移动端 AppBar actions / 桌面端 hover 滑出的平台分离菜单模式
metadata:
  type: project
---

# 平台分离菜单模式

移动端和桌面端使用不同的菜单承载方式，不复用同一个 bar。

## 模式

**移动端** (`Platform.isAndroid || Platform.isIOS`):
- `TopMenuOverlay` 直接返回 `widget.child`，不渲染额外 bar
- 菜单按钮放入各页面 `AppBar.actions`
- 使用 `IconButton`，配合 `if` 条件控制显隐

**桌面端** (else):
- `TopMenuOverlay` 渲染 `MouseRegion` + `AnimatedSlide`
- hover 顶部 5px 触发滑出，离开 >60px 延迟 400ms 隐藏

## 为什么不用 Stack + Padding

早期尝试在 Stack 内给 child 加顶部 padding 避让菜单栏，导致：
- AppBar 被推挤变粗
- 菜单栏渲染为黑线
- Scaffold 布局冲突

**教训**：不要试图在 Scaffold 外包一层 bar——直接用 Scaffold 自带的 AppBar。

## 应用位置

- [[home_screen.dart]] — 首页 3 个按钮（批量选择、背景色、设置）
- [[reader_screen.dart]] — 阅读页 5 个按钮（标注、书签、格式转换、背景色、设置）
- [[top_menu_bar.dart]] — `_isMobile` 分支实现透视

**Why:** 复用系统 AppBar 是移动端最干净的菜单承载方式，避免多余 DOM 层级和布局冲突
**How to apply:** 新增页面的菜单按钮 → 移动端放 AppBar.actions，桌面端放 TopMenuOverlay.buttons
