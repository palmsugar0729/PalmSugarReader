# CLAUDE.md

> PalmSugarReader — 轻量跨平台阅读器，Flutter 项目。面向 AI 助手的快速上手指南。

## 常用命令

```bash
# 进入 Flutter 项目
cd codes/palm_sugar_reader

# 获取依赖
flutter pub get

# Windows 构建与运行
flutter build windows --release
# 输出: build/windows/x64/runner/Release/palm_sugar_reader.exe

# Android 构建（APK）
flutter build apk --debug       # 快速测试
flutter build apk --release     # 正式包

# 分析/检查
flutter analyze                 # 静态分析
flutter test                    # 跑测试

# 查看已配好的平台
flutter devices                 # 列出可用设备
```

## 项目结构

```
codes/palm_sugar_reader/lib/
├── main.dart              # 入口 + SettingsProvider
├── theme.dart             # 鼠尾草绿 #A3C1AD
├── models/                # book.dart, annotation.dart
├── screens/               # home_screen, reader_screen, settings_screen
├── readers/               # pdf_reader, epub_reader, txt_reader, markdown_reader, image_reader
├── converters/            # format_converter (路由) + 各转换器 (md→pdf, md→epub, image→pdf, txt↔md)
├── services/              # bookmark_service, settings_service, annotation_service
├── widgets/               # top_menu_bar, annotation_layer, color_picker
└── utils/                 # file_utils, encoding_utils
```

## 关键设计

- **格式转换以 MD 为枢纽**：TXT→MD, EPUB→MD, MD→PDF, MD→EPUB, MD→TXT, 图片→PDF。链式转换通过 MD 中转（如 EPUB→MD→PDF）
- **标注坐标归一化**：全部存 0~1 相对比例，天然缩放跟随。AnnotationLayer 在 `!enabled` 时直接返回 child，不叠加手势
- **状态管理**：SettingsProvider (InheritedNotifier + ChangeNotifier) 管全局主题/字号，页面级用 StatefulWidget + setState
- **ReaderScreen 分发**：switch(book.format) → 对应 Reader Widget

## 已知陷阱

- InteractiveViewer 缩放用矩阵乘法，不要直接覆盖（会丢平移分量）
- 批量导入要用 Future.wait() 等异步完成，否则数据丢失
- SnackBar + Navigator.push 同帧冲突 → 用 addPostFrameCallback 延迟
- MD→EPUB 需要 EPUB 3 的 nav.xhtml，否则现代阅读器拒绝
- `archive` 包需在 pubspec.yaml 显式声明（epubx 间接依赖不够）

## 平台现状

- Windows ✅ 主力开发
- Android 🟡 APK 构建成功，全部格式可用，触控适配基本完成
- iOS 🟡 目录已配好，无 Mac 无法构建
