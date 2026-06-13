---
name: p0-multiformat-progress
description: P0 多格式阅读功能开发进度记录
metadata:
  type: project
---

## 进度概览（截至 2026-06-13）

### 已完成 ✅

1. **项目初始化**：Flutter 3.44.1 项目，支持 Windows / Android / iOS
2. **主色调**：`#A3C1AD`（鼠尾草绿），完整 Material3 主题
3. **基础框架**：首页 + 阅读器路由壳 + 文件类型识别
4. **5 种格式阅读器**：图片、TXT、Markdown、EPUB、PDF
5. **TXT 多编码检测**：UTF-8 → GBK → Shift_JIS → Latin1
6. **Markdown 公式渲染**：LaTeX 数学公式支持
7. **首页批量删除**：滑动移除、选择模式、全选
8. **格式转换**：TXT ↔ MD、EPUB → MD、MD → PDF（含链式中转）
9. **MD → PDF 中日文字体**：Noto Sans SC（17MB，SIL 开源）
10. **PDF 缩放控制**：右下角 +/- 按钮
11. **书签/文件记忆**：JSON 持久化（仅 PDF/EPUB），重启恢复
12. **设置页面**：占位空页面 + 首页齿轮图标
13. **EPUB 大文件修复**：同步等待解析完成
14. **左滑优化**：阈值 25%，动画 200ms

### 待完成 ⏳

15. **标注系统**：高亮、划线、批注
16. **缩放增强**：Ctrl+滚轮、百分比滑条
17. **右键上下文菜单**：重命名、复制剪切粘贴
18. **批量导入**：同目录相似文件自动发现
19. **设置内容填充**：各项具体设置

### 当前代码状态

- `flutter analyze` 零错误 ✅
- `flutter build windows --release` 通过 ✅
- Release 体积：62MB（含 Noto Sans SC 字体 17MB）

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
