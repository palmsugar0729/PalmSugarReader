# 讨论存档 — 2026-06-19（下午）

> 主题：书签功能 + 键盘导航 + EPUB 进度恢复 + Bug 修复

---

## 一、PRD 4.3.1 字体策略收尾

**讨论结论**：MVP 阶段够用，无需渗透到每个阅读器。

- PDF：`pdfrx` 自动使用内嵌字体
- EPUB/MD/TXT：Flutter 默认调系统 CJK 字体（中日文用户系统已覆盖）
- MD→PDF 转换：已有完整字体优先级链（用户导入 → 系统 → 内置 NotoSansSC-Regular）
- 极端场景（英文 Windows 打开中文 TXT）不是目标用户群

---

## 二、PRD 4.2 书签功能

### 数据模型
- `Bookmark` 类：id、filePath、pageNumber、chapterIndex/Title、position、createdAt
- per-file JSON 持久化，目录 `{appData}/bookmarks/bm_{hash}.json`
- 与 `AnnotationService` 同模式

### 服务层
- `BookmarkStorage`：静态方法，CRUD + generateId
- 与旧 `BookmarkService`（最近文件）命名区分

### UI
- 顶部菜单栏新增书签按钮（`Icons.bookmark`），仅 PDF/EPUB 可点
- 底部弹窗列表（`DraggableScrollableSheet`）：添加当前页 / 点击跳转 / 滑动删除
- 页码圆圈头像 + 章节标题 + 时间戳

### 关键决策
- 内存优先，磁盘异步跟随 —— `_addBookmark` 先更新 `_bookmarks` 再写磁盘
- `_bookmarksLoaded` 标记位：`_showBookmarkSheet` 只首次从磁盘读，后续用内存
- `_saveForFile` 不再静默吞错，异常上抛到 UI 层显示红色 SnackBar

---

## 三、键盘导航增强

### PDF
- **根因**：`Focus.onKeyEvent` 被 pdfrx 内部 Focus 拦截
- **修复**：改用 `HardwareKeyboard.instance.addHandler()`，硬件级拦截
- 快捷键：PgUp/PgDn/↑↓/Home/End/Space/Shift+Space

### TXT / Markdown
- **根因**：完全没有键盘处理代码
- **修复**：添加 `ScrollController` + `HardwareKeyboard` handler + `LayoutBuilder` 获取视口高度
- 快捷键：↑↓（行滚动）/ PgUp/PgDn（翻页）/ Home/End / Space / Shift+Space

### 设计决策
- 翻页距离 = 视口高度 × 80%
- 行滚动距离 = 60px
- 选择 `HardwareKeyboard` 而非 `Focus.onKeyEvent`：子 widget（pdfrx、PageView）拦截 Focus 事件

---

## 四、Bug 修复

### 4.1 书签 RangeError 崩溃
```
RangeError (end): Invalid value: Not in inclusive range 0..6: 12
```
- **根因**：`path.hashCode.toRadixString(36).substring(0, 12)` —— hashCode 转 36 进制可能只有 7 位
- **修复**：`path.hashCode.abs().toRadixString(36).padLeft(12, '0')`
- **影响范围**：`BookmarkStorage` + `AnnotationService`（同样的隐患，一并修复）

### 4.2 EPUB 构建期 setState
```
setState() or markNeedsBuild() called during build.
EpubReaderState._loadChapter (line 210)
```
- **根因**：`PageView.builder` → `_buildPage` → 章节未缓存时直接调 `_loadChapter` → `setState`
- **修复**：`WidgetsBinding.instance.addPostFrameCallback` 延迟到帧末

### 4.3 EPUB 进度恢复失效
- **根因**：`_restoreProgress` 恢复了正确的章节号，但 `PageController(initialPage: 0)` 永远从首页开始
- **修复**：`PageController(initialPage: _currentChapterIndex)`

### 4.4 PDF Home/End/PgUp/PgDn 失效
- 同第三节，改用 `HardwareKeyboard` API

---

## 五、技术笔记

### 5.1 `HardwareKeyboard` vs `Focus.onKeyEvent`
- `Focus.onKeyEvent`：依赖 Flutter Focus 树，子 widget 可能拦截
- `HardwareKeyboard.instance.addHandler`：硬件级，所有事件都会到达
- **适用场景**：当子 widget（如 pdfrx、PageView）有自己的 Focus 节点时

### 5.2 Flutter 构建期限制
- `setState` / `markNeedsBuild` 不能在 `build()` 方法及其同步调用链中调用
- 解决：`WidgetsBinding.instance.addPostFrameCallback` 或 `SchedulerBinding`

### 5.3 `path.hashCode` 不可靠
- `String.hashCode` 返回的 int 转 base-36 后长度不定
- 用于生成文件名时必须 `padLeft` 保证最小长度

### 5.4 内存优先数据流
- 用户操作 → 立即更新内存（setState）→ 异步写磁盘
- 优点：UI 即时响应 + 磁盘故障不影响当前会话
- 适用：书签、标注等用户期望即时反馈的功能

---

## 六、文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/models/bookmark.dart` | 新建 | 书签数据模型 |
| `lib/services/bookmark_storage.dart` | 新建 | 书签持久化服务 |
| `lib/screens/reader_screen.dart` | 修改 | 书签按钮 + 底部弹窗 + 内存优先数据流 |
| `lib/readers/pdf_reader.dart` | 修改 | HardwareKeyboard + 公开位置 API + Space 翻页 |
| `lib/readers/epub_reader.dart` | 修改 | 公开位置 API + setState 延迟 + PageController 修复 |
| `lib/readers/txt_reader.dart` | 修改 | 键盘导航 + ScrollController |
| `lib/readers/markdown_reader.dart` | 修改 | 键盘导航 + ScrollController |
| `lib/services/annotation_service.dart` | 修改 | _hashPath padLeft 修复 |
| `docs/PRD.md` | 修改 | 4.2 + 4.3.1 标记完成 |
| `README.md` | 修改 | 书签/键盘/进度恢复 更新 |
| `MEMORY.md` | 新建 | Memory 索引 |
| `memory/p0-multiformat-progress.md` | 修改 | 进度更新到 2026-06-19 |
| `notes/2026-06-19_开发日志.md` | 修改 | 追加下午内容 |
