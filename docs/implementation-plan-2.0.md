# PalmSugarReader 2.0 实施计划

> 基于 PRD v0.5 | 更新：2026-06-19

---

## 总览

```
Phase 1: 基础设施    ██████████ ✅ 完成
Phase 2: 设置+主题   ██████████ ✅ 完成
Phase 3: 字体策略    ██████████ ✅ 完成
Phase 4: 标注系统    ██████████ ✅ 完成
Phase 5: 格式转换    ██████████ ✅ 完成 (2026-06-19)
Phase 6: 延后        ██░░░░░░░░ 🔜 用户系统本地mock + 语言入口 + 设置字号
```

### MVP 额外完成

| 功能 | 日期 | 说明 |
|------|------|------|
| 书签 | 2026-06-19 | 手动书签增删查跳转，per-file JSON |
| 键盘增强 | 2026-06-19 | 全格式 PgUp/PgDn/Home/End/Space |
| EPUB 进度恢复 | 2026-06-19 | 退出后再进自动回到上次章节 |
| 文件拖拽 | 2026-06-19 | desktop_drop 拖入打开 |

---

## 总览

```
Phase 1: 基础设施    ████░░░░░░  2-3h   右键精简 + 顶部菜单栏
Phase 2: 设置+主题   ████░░░░░░  2-3h   设置填充 + 背景色 + 字号
Phase 3: 字体策略    ███░░░░░░░  1-2h   精简字体 + 系统字体优先
Phase 4: 标注系统    ██████░░░░  4-6h   高亮/划线/批注 + 色盘
Phase 5: 格式转换    ████░░░░░░  2-3h   MD→TXT + 图片→PDF + MD→EPUB
Phase 6: 延后        ██░░░░░░░░  -      用户系统本地mock + 语言入口
```

---

## Phase 1: 基础设施

### 1.1 右键菜单精简
- **文件**：[home_screen.dart](codes/palm_sugar_reader/lib/screens/home_screen.dart)
- 删除"复制文件路径"菜单项
- 缩小 `PopupMenuItem` 高度和内边距
- 缩小菜单文字字号
- **预计**：15min

### 1.2 顶部菜单栏
- **新建**：`lib/widgets/top_menu_bar.dart`
- **交互**：`MouseRegion` 监听顶部区域 → `AnimatedSlide`/`AnimatedOpacity` 滑入滑出
- **按钮列表**（从左到右）：

| 按钮 | 图标 | 可用场景 |
|------|------|----------|
| 标注工具 | `edit` | 仅阅读界面 |
| 格式转换 | `transform` | 仅阅读界面 |
| 字号 | `format_size` | 仅阅读界面 |
| 背景色 | `brightness_6` | 全局 |
| 批量选择 | `checklist` | 仅主界面 |
| 账号 | `person_outline` | 全局（先灰色占位） |
| 设置 | `settings_outlined` | 全局 |

- 整合到以下界面：`HomeScreen`、`ReaderScreen`
- `ReaderScreen` 需重构：将 AppBar 的转换菜单移到顶部菜单栏，AppBar 简化
- **预计**：2h

---

## Phase 2: 设置 + 主题

### 2.1 设置页面填充
- **文件**：[settings_screen.dart](codes/palm_sugar_reader/lib/screens/settings_screen.dart)

| 设置项 | 类型 | 说明 |
|--------|------|------|
| 批量导入 | `SwitchListTile` | 默认开启 |
| 默认字体大小 | `SegmentedButton` | 小(14) / 中(16) / 大(20) |
| 额外字体导入 | `ListTile` → 文件选择 | 导入 .ttf/.otf 作为 fallback |
| 语言 | `ListTile` → 灰显 | 先占位，显示"中文" |
| 帮助和支持 | `ListTile` → 关于页 | 版本号、开源许可、FAQ |
| 清除历史 | `ListTile` → 确认弹窗 | 清空书签和最近文件 |

### 2.2 背景色切换
- 在主界面（HomeScreen）和设置页各加一个切换入口
- 三态：默认白 / 暗色 / 跟随系统
- 通过 `ValueNotifier` + `ThemeMode` 全局切换
- 字体大小也通过全局 `ValueNotifier` 传递到各阅读器
- **预计**：2h

---

## Phase 3: 字体策略

### 3.1 替换内置字体
- 下载 `NotoSansSC-Regular.ttf`（~5MB）替换当前 `NotoSansSC-VF.ttf`（17MB）
- 更新 `pubspec.yaml` 的 assets 路径
- **预计**：15min

### 3.2 系统字体优先
- **文件**：[md_pdf_converter.dart](codes/palm_sugar_reader/lib/converters/md_pdf_converter.dart)
- 渲染优先级：PDF 内嵌字体 → 系统已安装字体 → 内置 Noto Regular → 用户导入字体
- Windows 系统字体查找：读注册表 `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` 或用 `dart:io` 遍历 `C:\Windows\Fonts\`
- 实现 `_findSystemCjkFont()` 函数
- **预计**：1h

### 3.3 设置页字体导入
- 与 Phase 2 的"额外字体导入"联动
- 导入的字体文件存到 app 数据目录，加入 fallback 列表
- **预计**：30min

---

## Phase 4: 标注系统

### 4.1 基础设施
- **新建**：`lib/services/annotation_service.dart` — 标注数据 CRUD（JSON 持久化，与原文分离）
- **新建**：`lib/models/annotation.dart` — 数据模型
  ```dart
  class Annotation {
    String id;
    String filePath;
    AnnotationType type; // highlight, underline, note
    int pageIndex;       // PDF 页码 或 EPUB globalPage
    Rect? bounds;        // 文字区域坐标
    String? selectedText;
    String? noteText;    // 批注文字
    Color color;
    double opacity;
    DateTime createdAt;
  }
  ```
- **预计**：1h

### 4.2 颜色选择器
- **新建**：`lib/widgets/color_picker.dart`
- 预置色块：黄/绿/蓝/粉/橙，一键选取
- 展开自定义：RGB/HEX 输入 + 不透明度滑块
- **预计**：1h

### 4.3 PDF 标注
- **文件**：[pdf_reader.dart](codes/palm_sugar_reader/lib/readers/pdf_reader.dart)
- pdfrx 已支持 `enableTextSelection: true`
- 利用其选择回调获取选中文字和区域
- 在 PDF 上方叠加 `CustomPaint` 层渲染高亮/划线
- 长按/右键选中文字后弹出标注工具栏（高亮/划线/批注/选色）
- **预计**：2h

### 4.4 EPUB 标注
- **文件**：[epub_reader.dart](codes/palm_sugar_reader/lib/readers/epub_reader.dart)
- flutter_html 的 `Html` 支持文字选择
- 利用 `onTapUp` + 选中检测
- 标注数据按 globalPage + 偏移量定位
- **预计**：2h

### 4.5 付费预留
- 在标注入口加一个简单的开关逻辑（`AnnotationService.isEnabled`）
- 暂时默认 true，后续只需改一个 bool 即可切换
- **预计**：15min

---

## Phase 5: 格式转换

### 5.1 MD → TXT
- **新建**：`lib/converters/md_txt_converter.dart`
- 剥离 Markdown 语法，提取纯文本
- 有之前 TXT→MD 的经验，反过来做即可
- **预计**：30min

### 5.2 图片 → PDF
- **新建**：`lib/converters/image_pdf_converter.dart`
- 单图：图贴到空白页 → 导出 PDF
- 多图：主界面多选 → 两种模式
  - 紧凑排列：按网格排列（2列），放得下就放同一页
  - 一图一页：每张图独立一页
- 多选入口：主界面选择模式 + 转换按钮，或在顶部菜单栏加入口
- 依赖现有的 `pdf` 包（已安装）
- **预计**：1.5h

### 5.3 MD → EPUB
- **新建**：`lib/converters/md_epub_converter.dart`
- 需要「格式设置」UI：章节划分规则、封面图、目录生成
- 格式设置弹窗：用户指定按 `#` / `##` 分章、是否自动生成目录
- 用 `epubx` 包写入 EPUB（`EpubWriter`）
- **预计**：2h

---

## Phase 6: 延后处理

### 6.1 用户系统本地 Mock
- 顶部菜单栏账号按钮：点击弹出"登录"占位弹窗
- 本地用设备 ID 模拟用户身份，暂不联网
- **预计**：30min（开发时顺手做）

### 6.2 语言入口
- 设置页已预留入口，灰显 + "中文"标签
- 等 i18n 基础设施搭好后再激活

---

## 依赖关系

```
Phase 1 (基础设施)
  └─ Phase 2 (设置+主题)
       ├─ Phase 3 (字体策略)
       │    └─ 设置页字体导入联动
       ├─ Phase 4 (标注系统)
       │    └─ 顶部菜单栏的标注入口
       └─ Phase 5 (格式转换)
            └─ 顶部菜单栏的转换入口
```

---

## 文件变更清单

| Phase | 新建 | 修改 | 删除 |
|-------|------|------|------|
| 1 | `lib/widgets/top_menu_bar.dart` | `home_screen.dart`, `reader_screen.dart` | - |
| 2 | - | `settings_screen.dart`, `theme.dart`, `main.dart` | - |
| 3 | - | `md_pdf_converter.dart`, `pubspec.yaml`, `assets/fonts/` | NotoSansSC-VF.ttf |
| 4 | `annotation_service.dart`, `annotation.dart`, `color_picker.dart` | `pdf_reader.dart`, `epub_reader.dart` | - |
| 5 | `md_txt_converter.dart`, `image_pdf_converter.dart`, `md_epub_converter.dart` | `format_converter.dart` | - |
