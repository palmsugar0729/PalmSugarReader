---
name: p0-multiformat-progress
description: P0 多格式阅读功能开发进度记录
metadata:
  type: project
---

## 进度概览（截至 2026-06-18）

### 已完成 ✅

1. **项目初始化**：Flutter 3.44.1 项目，支持 Windows / Android / iOS
2. **主色调**：`#A3C1AD`（鼠尾草绿），完整 Material3 主题
3. **基础框架**：首页 + 阅读器路由壳 + 文件类型识别
4. **多格式阅读器**：图片、TXT、Markdown、EPUB（翻页）、PDF
5. **TXT 多编码检测**：UTF-8 → GBK → Shift_JIS → Latin1
6. **Markdown 公式渲染**：LaTeX 数学公式支持
7. **首页批量删除**：滑动移除、选择模式、全选
8. **格式转换**：TXT ↔ MD、EPUB → MD、MD → PDF（含链式中转）
9. **MD → PDF 中日文字体**：Noto Sans SC VF（17MB，待精简为单字重 5-6MB）
10. **PDF 缩放控制**：+/- 按钮 + Ctrl+滚轮 + 百分比滑条（25%~500%）
11. **书签/文件记忆**：JSON 持久化，重启恢复
12. **设置页面**：占位空页面 + 首页齿轮图标
13. **EPUB 翻页阅读器**：基于 epubx 懒加载 + PageView 翻页，告别滚动，秒开大文件
14. **左滑优化**：阈值 25%，动画 200ms
15. **右键上下文菜单**：重命名文件、删除记录（待精简）
16. **批量导入**：同目录可读文件自动发现，一键导入
17. **标注图层系统**：统一 AnnotationLayer 组件，自由拖拽画高亮/划线/批注便签，相对坐标归一化，缩放跟随
18. **标注粗细选择**：颜色选择器集成粗细滑条（2~40px），固定高度拖拽
19. **键盘导航**：PDF ↑↓翻页、EPUB ←→翻页、TXT/MD 原生滚动
20. **批注（浮动便签）**：点击放置可拖动便签，点击查看/编辑文字，N 标记+文字预览
21. **标注联动删除**：书架删文件→自动清理标注 JSON

### 2.0 路线图（讨论完毕，待开发）

详见 [docs/needs_2.0.md](docs/needs_2.0.md)

**字体**：✅ 方案3 — 系统字体优先，内置 NotoSansSC-Regular（10MB，省 7MB）
**标注系统**：✅ 统一图层 + 自由拖拽 + 浮动便签批注 + 粗细选择 + 颜色选择器
**设置填充**：✅ 批量导入开关、字号三档(14/18/24)、语言占位、字体导入、帮助、背景色
**顶部菜单栏**：✅ 鼠标悬停展开，标注/转换/字号/背景/账号/设置
**右键菜单**：✅ 精简为重命名 + 删除
**格式转换**：MD→EPUB（需格式设置）、图片→PDF
**用户系统**：腾讯云服务器，测试阶段本地模拟，发布前接入

### 当前代码状态

- `flutter analyze` 零错误 ✅
- `flutter build windows --release` 通过 ✅
- Release 体积：62MB（含 Noto Sans SC VF 17MB → 待精简）
- 已移除依赖：`epub_view`（替换为自研翻页阅读器）

### 新增文件（2026-06-13）

- [lib/converters/format_converter.dart](codes/palm_sugar_reader/lib/converters/format_converter.dart)
- [lib/converters/txt_md_converter.dart](codes/palm_sugar_reader/lib/converters/txt_md_converter.dart)
- [lib/converters/epub_md_converter.dart](codes/palm_sugar_reader/lib/converters/epub_md_converter.dart)
- [lib/converters/md_pdf_converter.dart](codes/palm_sugar_reader/lib/converters/md_pdf_converter.dart)
- [lib/utils/encoding_utils.dart](codes/palm_sugar_reader/lib/utils/encoding_utils.dart)
- [lib/services/bookmark_service.dart](codes/palm_sugar_reader/lib/services/bookmark_service.dart)
- [lib/screens/settings_screen.dart](codes/palm_sugar_reader/lib/screens/settings_screen.dart)

### Bug 修复记录

- [docs/bugs/bug-collection.md](docs/bugs/bug-collection.md) — #4 MD→PDF 字体、#5 EPUB 大文件跳页、#6 左滑动画
