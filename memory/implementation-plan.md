---
name: implementation-plan
description: 2.0 实施计划六个阶段的执行顺序和内容
metadata:
  type: project
---

# 2.0 实施计划

详见 [[p0-multiformat-progress]] 和 [docs/implementation-plan-2.0.md](codes/../docs/implementation-plan-2.0.md)

## 执行顺序

1. **Phase 1** — 右键精简 + 顶部菜单栏（基础设施）
2. **Phase 2** — 设置填充 + 背景色/字号切换
3. **Phase 3** — 字体策略（精简 + 系统字体优先）
4. **Phase 4** — 标注系统（高亮/划线/批注 + 色盘）
5. **Phase 5** — 格式转换（MD→TXT + 图片→PDF + MD→EPUB）
6. **Phase 6** — 延后（用户系统本地 mock + 语言入口 + 设置字号功能）

## 当前状态

- Phase 1 ✅ 完成 (2026-06-14) — 右键精简 + 顶部菜单栏
- Phase 2 ✅ 完成 (2026-06-14) — 设置填充 + 背景色/字号
- Phase 3 ✅ 完成 (2026-06-18) — 字体精简 + 系统字体优先
- Phase 4 ✅ 完成 (2026-06-18) — 标注系统（统一图层+自由拖拽+批注便签+粗细+键盘）
- Phase 5 ✅ 完成 (2026-06-19) — 格式转换（MD→TXT + 图片→PDF + MD→EPUB）
- Phase 6 🔜 延后 — 用户系统本地 mock + 语言入口 + 设置字号功能

### 额外完成（超出原计划）

- **书签功能** (2026-06-19) — 手动书签增删查跳转，per-file JSON 持久化
- **键盘导航增强** (2026-06-19) — 全格式 PgUp/PgDn/Home/End/Space/Shift+Space
- **EPUB 进度恢复** (2026-06-19) — 退出后再进自动回到上次阅读章节
- **外部文件拖拽** (2026-06-19) — `desktop_drop` 拖入直接打开
- **Bug 修复** — #4~#13 共 10 个 bug

## 代码已推送 (2026-06-18)

- Commit `9a5b383`: Phase 2-4 全部改动（33 files, +3949/-465）
- 用户手动 push 到 `origin/main`
