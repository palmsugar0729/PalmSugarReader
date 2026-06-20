---
date: 2026-06-20
tags:
  - bug
  - android
  - ui
---

# Bug: 移动端顶部菜单栏与内容重叠

> 状态：✅ 已修复 | 版本：v1.0 Android

## 现象

移动端 `TopMenuOverlay` 使用 `Stack` 叠加菜单栏在内容上方，导致：
1. 菜单栏覆盖在列表/阅读内容顶部，遮挡内容
2. 菜单栏下方的按钮/文字无法点击（点击穿透到上层 bar）

## 根因

`TopMenuOverlay` 最初为桌面端设计——`MouseRegion` + `AnimatedSlide` 滑出菜单栏，平时隐藏，所以用 `Stack` 叠加是正确的。

移到移动端时，改为常驻显示但没改变布局方式，菜单栏仍然叠加在内容上方。

## 修复

废弃移动端的 `TopMenuOverlay` 独立 bar 方案：
- `TopMenuOverlay` 在移动端直接返回 `widget.child`（透传）
- 菜单按钮改为放入各页面 `AppBar.actions`
- 使用 `Platform.isAndroid || Platform.isIOS` 条件分支

修复文件：
- [[top_menu_bar.dart]] — `_isMobile` 分支返回 `widget.child`
- [[home_screen.dart]] — `_buildNormalAppBar()` 添加 `actions`
- [[reader_screen.dart]] — `AppBar` 添加 `actions`
