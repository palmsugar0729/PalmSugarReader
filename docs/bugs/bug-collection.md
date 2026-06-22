---
name: bug-collection
description: PalmSugarReader 已知问题、Bug 与修复记录汇总
metadata:
  type: project
---

# PalmSugarReader Bug & 问题收集

> 本文档汇总开发过程中发现的问题、用户反馈的 Bug 及修复状态。
> 格式：`[状态] 问题描述 → 解决方案/备注`

---

## 🟢 已修复

### 1. Markdown 内联公式未渲染
...（保持原有内容不变）...

### 3. `epubx` 的 `EpubReader` 类名冲突
...（保持原有内容不变）...

### 4. MD → PDF 中文/日文渲染为 □×（方框+叉号）

- **发现时间**：2026-06-13（用户测试反馈）
- **现象**：Markdown 转 PDF 后，所有中文字符显示为方框带 ×（tofu），英文/数字/符号正常
- **根因**：`pdf` 包默认使用 Helvetica/Courier 等西文字体，不包含 CJK 字形
- **修复方案**：
  - 引入 `NotoSansSC-VF.ttf`（思源黑体变量字体，17MB，SIL 开源许可证）
  - 注册为 Flutter assets，运行时通过 `rootBundle.load()` 加载
  - 所有 `pw.TextStyle` 统一使用 CJK 字体
  - 字体覆盖：简体中文、繁体中文、日文汉字、假名、拉丁字符
- **副作用**：Release 包体积从 45MB 增至 62MB
- **相关文件**：[lib/converters/md_pdf_converter.dart](../../codes/palm_sugar_reader/lib/converters/md_pdf_converter.dart)
- **截图**：[assets/bug/2026-06-13_bug_001.png](../../assets/bug/2026-06-13_bug_001.png)

### 5. EPUB 大文件加载卡顿并跳页

- **发现时间**：2026-06-13（用户测试反馈）
- **现象**：大 EPUB 文件加载后显示空白或突然跳到最后/第一页
- **根因**：`_loadEpub()` 在 `EpubController` 创建后立即设置 `_isLoading = false`，此时 `Future<EpubBook>` 尚未完成。`epub_view` 在文档未就绪时渲染导致异常跳页
- **修复方案**：
  - 改为 `await EpubReader.readBook(bytes)` 同步等待解析完成
  - 使用 `Future.value(epubBook)` 创建已就绪的 Future 传给 Controller
  - `setState` 仅在 EPUB 完全解析后才隐藏 loading 状态
- **相关文件**：[lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)

### 6. 首页左滑删除动画过度

- **发现时间**：2026-06-13（用户测试反馈）
- **现象**：左滑删除时红色背景铺满整行，动画幅度过大
- **修复方案**：
  - 减小滑动阈值：`dismissThresholds: {DismissDirection.endToStart: 0.25}`（默认 0.5）
  - 加快动画：`movementDuration: Duration(milliseconds: 200)`（默认 300ms）
- **相关文件**：[lib/screens/home_screen.dart](../../codes/palm_sugar_reader/lib/screens/home_screen.dart)

### 10. 书签添加后列表为空 / 关文档后丢失（2026-06-19）

- **发现时间**：2026-06-19
- **报告人**：@palmsugar
- **现象**：添加书签后 snackbar 确认成功，但书签列表为空。关闭文档再打开书签消失。
- **根因**：
  1. `path.hashCode.toRadixString(36).substring(0, 12)` RangeError —— hashCode 转 base-36 后可能不足 12 位
  2. 数据流设计错误：每次打开书签列表都从磁盘加载 → `setState` 覆盖内存
- **修复**：
  1. `abs().toRadixString(36).padLeft(12, '0')` 替代 `substring`
  2. 内存优先策略：增/删先更新 `_bookmarks`，再异步写磁盘
  3. `_bookmarksLoaded` 标记位：只在首次从磁盘读
  4. `_saveForFile` 异常上抛，UI 层 catch 并显示红色 SnackBar
- **相关文件**：[lib/services/bookmark_storage.dart](../../codes/palm_sugar_reader/lib/services/bookmark_storage.dart) · [lib/services/annotation_service.dart](../../codes/palm_sugar_reader/lib/services/annotation_service.dart) · [lib/screens/reader_screen.dart](../../codes/palm_sugar_reader/lib/screens/reader_screen.dart)
- **截图**：[assets/bug/2026-06-19_bug_005.png](../../assets/bug/2026-06-19_bug_005.png)
- **状态**：🟢 已修复

### 11. EPUB 构建期 setState 崩溃（2026-06-19）

- **发现时间**：2026-06-19
- **报告人**：@palmsugar
- **现象**：打开 EPUB 时崩溃：`setState() or markNeedsBuild() called during build`
- **根因**：`PageView.builder` 的 `itemBuilder`（构建期）→ `_buildPage` → 章节未缓存时直接调 `_loadChapter` → `setState(() => _isLoadingContent = true)`
- **修复**：`WidgetsBinding.instance.addPostFrameCallback` 延迟章节加载到帧末
- **相关文件**：[lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)
- **状态**：🟢 已修复

### 12. PDF / MD / TXT 键盘导航失效（2026-06-19）

- **发现时间**：2026-06-19
- **报告人**：@palmsugar
- **现象**：PDF PgUp/PgDn/Home/End 无反应；MD/TXT 完全没有键盘功能
- **根因**：
  1. PDF：`Focus.onKeyEvent` 被 pdfrx 内部 Focus 拦截
  2. MD/TXT：从未实现键盘处理
- **修复**：
  1. 全部改用 `HardwareKeyboard.instance.addHandler()` 硬件级拦截
  2. MD/TXT 添加 `ScrollController` + `LayoutBuilder` 视口高度计算
  3. 新增 Space/Shift+Space 备用翻页键
- **相关文件**：[lib/readers/pdf_reader.dart](../../codes/palm_sugar_reader/lib/readers/pdf_reader.dart) · [lib/readers/txt_reader.dart](../../codes/palm_sugar_reader/lib/readers/txt_reader.dart) · [lib/readers/markdown_reader.dart](../../codes/palm_sugar_reader/lib/readers/markdown_reader.dart)
- **状态**：🟢 已修复

### 13. EPUB 退出后再进从首页开始（2026-06-19）

- **发现时间**：2026-06-19
- **报告人**：@palmsugar
- **现象**：EPUB 退出后再进总是从第一章开始，不恢复上次位置
- **根因**：`_restoreProgress` 正确恢复了 `_currentChapterIndex`，但 `PageController(initialPage: 0)` 死写从首页开始
- **修复**：`_pageController?.dispose(); _pageController = PageController(initialPage: _currentChapterIndex);`
- **相关文件**：[lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)
- **状态**：🟢 已修复

### 14. 退出标注模式后标注不可见（2026-06-22）

- **发现时间**：2026-06-22
- **报告人**：@palmsugar
- **现象**：Android 平板端在标注模式内画的标注（高亮/画笔等），退出标注模式后全部看不见，再进入标注模式才显示
- **根因**：`AnnotationLayer.build()` 中 `if (!widget.enabled) return widget.child;` 直接跳过了整个 Stack，包括渲染已保存标注的 `CustomPaint`（`_AnnPainter`）
- **修复**：拆分渲染与交互 — `CustomPaint` 始终存在于 Stack 中，`Listener`/`GestureDetector` 仅在 `enabled` 时叠加；`_buildPreview()` 也加 `widget.enabled` 条件
- **相关文件**：[lib/widgets/annotation_layer.dart](../../codes/palm_sugar_reader/lib/widgets/annotation_layer.dart)
- **状态**：🟢 已修复

### 15. EPUB 标注模式无退出按钮（2026-06-22）

- **发现时间**：2026-06-22
- **报告人**：@palmsugar
- **现象**：EPUB 阅读器进入标注模式后，没有"退出"按钮，用户只能通过再次长按触发 dialog 来退出（但 dialog 取消不会改变模式）
- **根因**：EPUB 阅读器缺少 `_buildIndicator()` 调用，PDF 和 Image 阅读器有此指示条但 EPUB 遗漏
- **修复**：新工具栏自带退出按钮，PDF/Image/EPUB 三端统一 — 工具行最右侧"✕退出"按钮
- **相关文件**：[lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)
- **状态**：🟢 已修复

---

## 🟡 已知问题 / 待优化

### 4. `flutter_markdown` 已标记 discontinued

- **发现时间**：2026-06-08
- **状态**：⚠️ 不影响功能，但官方推荐迁移
- **说明**：`flutter_markdown: ^0.7.7+1` 已被 pub.dev 标记为 discontinued，官方替代方案为 `flutter_markdown_plus`
- **影响**：当前配合 `flutter_markdown_latex` 使用正常，但长期建议迁移
- **计划**：P1 阶段评估迁移到 `flutter_markdown_plus`

### 5. 首页文件列表无持久化

- **发现时间**：2026-06-08
- **状态**：📋 设计如此（MVP 阶段），但用户可能期望重启后保留历史
- **说明**：`_recentBooks` 保存在内存中，应用重启后清空
- **计划**：后续引入 `shared_preferences` 或 SQLite 做本地持久化

### 8. PDF/图片缩放后视角无法平移（2026-06-18）

- **发现时间**：2026-06-18
- **报告人**：@palmsugar
- **现象**：PDF 用 Ctrl+滚轮或 +/- 按钮放大后，内容超出屏幕边缘部分无法看到，鼠标拖拽无法平移视角。图片同理。
- **期望行为**：放大后鼠标可拖拽平移视角到内容任意位置
- **实际行为**：视角锁定，超出屏幕内容不可见
- **尝试修复**：去掉 `pageAnchor: all`、去掉 `CallbackShortcuts` 包裹、去掉 `boundaryMargin` 限制——均无效
- **状态**：🟡 待修复

### 9. 标注模式退出后缩放比例未更新（2026-06-18）

- **发现时间**：2026-06-18
- **现象**：标注模式下禁用 InteractiveViewer 手势，退出后有时缩放状态未恢复
- **状态**：🟡 待确认

---

## 🔴 环境问题（非代码 Bug）

### 6. Windows 桌面端构建需开发者模式

- **发现时间**：2026-06-08
- **现象**：`flutter pub get` 报错 "Building with plugins requires symlink support"
- **根因**：含原生插件的包（`pdfrx`、`file_picker`）在 Windows 上构建需要创建符号链接
- **解决**：开启 Windows 系统设置中的「开发者模式」
- **操作**：运行 `start ms-settings:developers` 或在「设置 → 隐私和安全性 → 开发者模式」中开启

### 7. Windows 桌面端构建需 Visual Studio C++ 工具链

- **发现时间**：2026-06-08
- **现象**：`flutter run -d windows` 报错 "Unable to find suitable Visual Studio toolchain"
- **根因**：未安装 Visual Studio 的 C++ 桌面开发工作负载
- **解决**：
  1. 安装 Visual Studio Community（免费）或 Build Tools
  2. 在 Visual Studio Installer 中勾选 **「使用 C++ 的桌面开发」** 工作负载
  3. 重新运行 `flutter run -d windows`

---

## 📝 反馈模板

发现新 Bug 时请按以下格式记录：

```markdown
### 编号. 问题标题

- **发现时间**：YYYY-MM-DD
- **报告人**：@用户名
- **现象**：
- **复现步骤**：
  1. ...
  2. ...
- **期望行为**：
- **实际行为**：
- **环境**：Windows / Android / iOS + Flutter 版本
- **相关文件**：
- **状态**：待修复 / 已修复 / 已知问题
```
