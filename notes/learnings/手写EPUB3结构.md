---
date: 2026-06-19
tags: [learning, epub, epub3, archive, xml, markdown]
project: PalmSugarReader
aliases: ["手写 EPUB3 结构"]
---

# 手写 EPUB3 结构

## 背景

实现 MD to EPUB 时需要生成 EPUB 文件。`epubx` 包的 `EpubWriter` 需要构造完整的 `EpubBook` 对象（含 `EpubSchema`、`EpubPackage` 等），过于复杂。选择用 `archive` 包手写 EPUB zip，更可控。

## 核心概念

### EPUB 3 最小文件清单

```
mimetype                           # 纯文本 application/epub+zip（不压缩，必须第一个）
META-INF/container.xml             # 指向 OPF
OEBPS/content.opf                  # 版本 3.0，包清单
OEBPS/nav.xhtml                    # EPUB 3 导航文档（必须带 epub:type="toc"）
OEBPS/toc.ncx                      # 兼容旧阅读器的 NCX 导航
OEBPS/style/style.css              # 样式表
OEBPS/text/chapter*.xhtml          # 章节内容
OEBPS/text/cover.xhtml             # 封面页（可选）
OEBPS/images/                      # 图片目录（可选）
```

### Markdown 转 XHTML

```dart
final htmlBody = md.markdownToHtml(chapter.content);
```

`markdown` 包自动转义 HTML 特殊字符（`&` to `&amp;`，`<` to `&lt;`），不需要额外转义。

### 分章逻辑

```dart
// 1. 扫描所有标题，检测最高级别
final headings = _detectHeadingLevels(lines);
final splitLevel = headings.contains(1) ? 1 : 2;

// 2. 按该级别切分
final prefix = '#' * splitLevel + ' ';
for (final line in lines) {
  if (line.startsWith(prefix)) {
    // 新章节
  }
}
```

### ZIP 打包

```dart
final archive = Archive();
archive.addFile(ArchiveFile.noCompress('mimetype', 20, utf8.encode('application/epub+zip')));
archive.addFile(ArchiveFile('META-INF/container.xml', ...));
// ...
return ZipEncoder().encode(archive);
```

## 踩过的坑

1. **mimetype 必须不压缩**：使用 `ArchiveFile.noCompress` 而非 `ArchiveFile`
2. **nav.xhtml 必须带 `epub:type="toc"`**：否则阅读器不识别目录
3. **OPF version 必须写 3.0**：写 2.0 的话 nav 的 properties 属性会被忽略
4. **spine 不包含 nav.xhtml**：nav 只在 manifest 中声明，不在阅读顺序中

## 参考

- Python 项目 `easy_EPUB_generator`（ebooklib 库结构参考）
- EPUB 3.2 规范
- 实际验证：Apple Books / 多看 / 微信读书
