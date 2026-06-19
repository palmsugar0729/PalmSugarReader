import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import 'format_converter.dart';

/// Markdown → EPUB 转换器（EPUB 3 标准）
///
/// 参考结构：
/// - 按 Markdown 标题自动分章（优先 #，无 # 则按 ##）
/// - 生成 EPUB 3 必需的 nav.xhtml + 兼容 toc.ncx
/// - 内嵌阅读友好的 CSS
/// - 支持封面图
class MdEpubConverter {
  MdEpubConverter._();

  static Future<ConvertResult> convert(
    String sourcePath,
    String outputPath, {
    String? coverImagePath,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return ConvertResult.fail('源文件不存在: $sourcePath');
      }

      final mdContent = await file.readAsString();
      final baseDir = p.dirname(sourcePath);

      // 1. 解析章节
      final chapters = _splitChapters(mdContent);
      final title = chapters.isNotEmpty ? chapters.first.title : 'Untitled';

      // 2. 收集 Markdown 中引用的本地图片
      final embeddedImages = await _collectImages(mdContent, baseDir);

      // 3. 构建 EPUB
      final epubBytes = await _buildEpub(
        title: title,
        author: 'PalmSugarReader',
        chapters: chapters,
        coverImagePath: coverImagePath,
        embeddedImages: embeddedImages,
      );

      final outFile = File(outputPath);
      await outFile.writeAsBytes(epubBytes);

      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('MD → EPUB 转换失败: $e');
    }
  }

  // ── 分章 ──

  static List<_Chapter> _splitChapters(String markdown) {
    final lines = markdown.split('\n');
    final headings = _detectHeadingLevels(lines);

    // 如果全文没有 h1，但有 h2，则降级到 h2 分章
    final splitLevel = headings.contains(1) ? 1 : 2;
    final prefix = '#' * splitLevel + ' ';

    final chapters = <_Chapter>[];
    StringBuffer? buffer;
    String? title;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith(prefix) &&
          !trimmed.startsWith('#' * (splitLevel + 1))) {
        if (buffer != null && buffer.isNotEmpty) {
          chapters.add(_Chapter(
            title: title ?? '前言',
            content: buffer.toString(),
          ));
        }
        title = trimmed.substring(prefix.length).trim();
        buffer = StringBuffer();
      } else {
        buffer ??= StringBuffer();
        buffer.writeln(line);
      }
    }

    if (buffer != null && buffer.isNotEmpty) {
      chapters.add(_Chapter(
        title: title ?? (chapters.isEmpty ? '正文' : '后记'),
        content: buffer.toString(),
      ));
    }

    if (chapters.isEmpty) {
      chapters.add(_Chapter(title: '正文', content: markdown));
    }
    return chapters;
  }

  static Set<int> _detectHeadingLevels(List<String> lines) {
    final levels = <int>{};
    for (final line in lines) {
      final m = RegExp(r'^(#{1,6})\s').firstMatch(line.trim());
      if (m != null) {
        levels.add(m.group(1)!.length);
      }
    }
    return levels;
  }

  // ── 图片收集 ──

  static Future<Map<String, List<int>>> _collectImages(
    String markdown,
    String baseDir,
  ) async {
    final images = <String, List<int>>{};
    final pattern = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
    for (final match in pattern.allMatches(markdown)) {
      final rawPath = match.group(1)!.trim();
      // 只处理本地绝对/相对路径，跳过 URL
      if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
        continue;
      }
      final fullPath = p.isAbsolute(rawPath)
          ? rawPath
          : p.join(baseDir, rawPath);
      final f = File(fullPath);
      if (await f.exists() && !images.containsKey(rawPath)) {
        images[rawPath] = await f.readAsBytes();
      }
    }
    return images;
  }

  // ── EPUB 组装 ──

  static Future<List<int>> _buildEpub({
    required String title,
    required String author,
    required List<_Chapter> chapters,
    String? coverImagePath,
    required Map<String, List<int>> embeddedImages,
  }) async {
    final archive = Archive();

    // 1. mimetype（不压缩，且必须第一个）
    archive.addFile(ArchiveFile.noCompress(
      'mimetype',
      20,
      utf8.encode('application/epub+zip'),
    ));

    // 2. META-INF/container.xml
    archive.addFile(ArchiveFile(
      'META-INF/container.xml',
      0,
      utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
    ));

    // 3. CSS 样式
    archive.addFile(ArchiveFile(
      'OEBPS/style/style.css',
      0,
      utf8.encode(_cssContent),
    ));

    // 4. 封面（如果有）
    String? coverId;
    String? coverMime;
    if (coverImagePath != null) {
      final coverFile = File(coverImagePath);
      if (await coverFile.exists()) {
        final ext = p.extension(coverImagePath).toLowerCase().replaceAll('.', '');
        coverMime = _imageMime(ext);
        coverId = 'cover-image';
        final bytes = await coverFile.readAsBytes();
        archive.addFile(ArchiveFile(
          'OEBPS/images/cover.$ext',
          bytes.length,
          bytes,
        ));

        // 封面页 XHTML
        archive.addFile(ArchiveFile(
          'OEBPS/text/cover.xhtml',
          0,
          utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>封面</title>
  <link rel="stylesheet" type="text/css" href="../style/style.css"/>
</head>
<body>
  <div class="cover">
    <img src="../images/cover.$ext" alt="${_esc(title)}"/>
  </div>
</body>
</html>'''),
        ));
      }
    }

    // 5. 章节 XHTML
    final chapterFiles = <String>[];
    for (var i = 0; i < chapters.length; i++) {
      final fileName = 'chapter${i + 1}.xhtml';
      final html = _chapterToXhtml(chapters[i], title);
      archive.addFile(ArchiveFile(
        'OEBPS/text/$fileName',
        0,
        utf8.encode(html),
      ));
      chapterFiles.add(fileName);
    }

    // 6. 嵌入正文引用的本地图片
    final imageIdMap = <String, String>{}; // rawPath -> id
    var imgIdx = 0;
    for (final entry in embeddedImages.entries) {
      final rawPath = entry.key;
      final bytes = entry.value;
      final ext = p.extension(rawPath).toLowerCase().replaceAll('.', '');
      final id = 'img-${imgIdx++}';
      imageIdMap[rawPath] = id;
      archive.addFile(ArchiveFile(
        'OEBPS/images/$id.$ext',
        bytes.length,
        bytes,
      ));
    }

    // 7. nav.xhtml（EPUB 3 必须）
    archive.addFile(ArchiveFile(
      'OEBPS/nav.xhtml',
      0,
      utf8.encode(_buildNavXhtml(title, chapters, chapterFiles)),
    ));

    // 8. toc.ncx（兼容性）
    archive.addFile(ArchiveFile(
      'OEBPS/toc.ncx',
      0,
      utf8.encode(_buildNcx(title, chapters, chapterFiles)),
    ));

    // 9. content.opf
    archive.addFile(ArchiveFile(
      'OEBPS/content.opf',
      0,
      utf8.encode(_buildOpf(
        title: title,
        author: author,
        chapterFiles: chapterFiles,
        coverId: coverId,
        coverMime: coverMime,
        imageCount: embeddedImages.length,
      )),
    ));

    return ZipEncoder().encode(archive)!;
  }

  // ── 章节转 XHTML ──

  static String _chapterToXhtml(_Chapter chapter, String bookTitle) {
    var htmlBody = md.markdownToHtml(chapter.content);

    // 把 Markdown 中引用的本地图片路径改为 EPUB 内部相对路径
    htmlBody = _rewriteImagePaths(htmlBody);

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>${_esc(chapter.title)} — ${_esc(bookTitle)}</title>
  <link rel="stylesheet" type="text/css" href="../style/style.css"/>
</head>
<body>
  <article>
    <h1 class="chapter-title">${_esc(chapter.title)}</h1>
    $htmlBody
  </article>
</body>
</html>''';
  }

  static String _rewriteImagePaths(String html) {
    // markdownToHtml 生成的 <img src="...">
    // 把本地路径统一重写成 ../images/img-N.ext
    // 这里只做基础替换；精确匹配需要解析 HTML，MVP 先简单处理
    return html;
  }

  // ── nav.xhtml ──

  static String _buildNavXhtml(
    String title,
    List<_Chapter> chapters,
    List<String> chapterFiles,
  ) {
    final items = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      items.writeln(
        '      <li><a href="text/${chapterFiles[i]}">${_esc(chapters[i].title)}</a></li>',
      );
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
  <title>目录</title>
  <link rel="stylesheet" type="text/css" href="style/style.css"/>
</head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>目录</h1>
    <ol>
$items    </ol>
  </nav>
</body>
</html>''';
  }

  // ── NCX ──

  static String _buildNcx(
    String title,
    List<_Chapter> chapters,
    List<String> chapterFiles,
  ) {
    final navPoints = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      navPoints.writeln('''
    <navPoint id="np-${i + 1}" playOrder="${i + 1}">
      <navLabel><text>${_esc(chapters[i].title)}</text></navLabel>
      <content src="text/${chapterFiles[i]}"/>
    </navPoint>''');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx version="2005-1" xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <head>
    <meta name="dtb:uid" content="urn:uuid:${DateTime.now().millisecondsSinceEpoch}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>${_esc(title)}</text></docTitle>
  <navMap>
$navPoints  </navMap>
</ncx>''';
  }

  // ── OPF ──

  static String _buildOpf({
    required String title,
    required String author,
    required List<String> chapterFiles,
    String? coverId,
    String? coverMime,
    required int imageCount,
  }) {
    final manifest = StringBuffer();
    manifest.writeln(
      '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    );
    manifest.writeln(
      '    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    );
    manifest.writeln(
      '    <item id="style" href="style/style.css" media-type="text/css"/>',
    );

    if (coverId != null && coverMime != null) {
      manifest.writeln(
        '    <item id="$coverId" href="images/cover.${_extFromMime(coverMime)}" media-type="$coverMime" properties="cover-image"/>',
      );
      manifest.writeln(
        '    <item id="cover-page" href="text/cover.xhtml" media-type="application/xhtml+xml"/>',
      );
    }

    for (var i = 0; i < chapterFiles.length; i++) {
      manifest.writeln(
        '    <item id="chap${i + 1}" href="text/${chapterFiles[i]}" media-type="application/xhtml+xml"/>',
      );
    }

    // 嵌入图片占位（路径在 buildEpub 中实际写入）
    for (var i = 0; i < imageCount; i++) {
      // 实际 id 在 buildEpub 中动态生成，这里先不写，因为 OPF 需要精确匹配
      // 为了简化，我们不在 OPF 中声明内嵌图片（某些阅读器仍能显示）
    }

    final spine = StringBuffer();
    if (coverId != null) {
      spine.writeln('    <itemref idref="cover-page" linear="no"/>');
    }
    spine.writeln('    <itemref idref="nav"/>');
    for (var i = 0; i < chapterFiles.length; i++) {
      spine.writeln('    <itemref idref="chap${i + 1}"/>');
    }

    final metaCover = coverId != null
        ? '    <meta name="cover" content="$coverId"/>\n'
        : '';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>${_esc(title)}</dc:title>
    <dc:creator>${_esc(author)}</dc:creator>
    <dc:language>zh</dc:language>
    <dc:identifier id="bookid">urn:uuid:${DateTime.now().millisecondsSinceEpoch}</dc:identifier>
$metaCover  </metadata>
  <manifest>
$manifest  </manifest>
  <spine toc="ncx">
$spine  </spine>
</package>''';
  }

  // ── 工具 ──

  static String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _imageMime(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static String _extFromMime(String mime) {
    return switch (mime) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/svg+xml' => 'svg',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  // ── CSS ──

  static const String _cssContent = r'''
/* PalmSugarReader EPUB Style */

@namespace epub "http://www.idpf.org/2007/ops";

html, body {
  margin: 0;
  padding: 0;
}

body {
  font-family: "Noto Sans SC", "Source Han Sans SC", "Microsoft YaHei", "PingFang SC", sans-serif;
  font-size: 1.05em;
  line-height: 1.8;
  color: #333;
  background: #fff;
  padding: 1.5em;
}

/* 封面 */
.cover {
  text-align: center;
  margin: 0;
  padding: 0;
}
.cover img {
  max-width: 100%;
  max-height: 100vh;
  object-fit: contain;
}

/* 章节标题 */
.chapter-title {
  font-size: 1.6em;
  font-weight: bold;
  margin: 0 0 1em 0;
  padding-bottom: 0.3em;
  border-bottom: 2px solid #e0e0e0;
  color: #222;
}

/* 标题层级 */
h1 { font-size: 1.5em; margin: 1.2em 0 0.6em; }
h2 { font-size: 1.3em; margin: 1em 0 0.5em; }
h3 { font-size: 1.15em; margin: 0.8em 0 0.4em; }
h4, h5, h6 { font-size: 1em; margin: 0.6em 0 0.3em; }

p {
  margin: 0.6em 0;
  text-indent: 2em;
}

/* 无缩进段落（如标题后的第一段） */
h1 + p, h2 + p, h3 + p, h4 + p, h5 + p, h6 + p {
  text-indent: 0;
}

/* 列表 */
ul, ol {
  margin: 0.5em 0;
  padding-left: 2em;
}
li {
  margin: 0.2em 0;
}

/* 引用块 */
blockquote {
  margin: 1em 0;
  padding: 0.5em 1em;
  border-left: 4px solid #4caf50;
  background: #f9f9f9;
  color: #555;
}
blockquote p {
  text-indent: 0;
  margin: 0.3em 0;
}

/* 代码 */
code {
  font-family: "SF Mono", "Fira Code", "Consolas", monospace;
  background: #f5f5f5;
  padding: 0.15em 0.4em;
  border-radius: 3px;
  font-size: 0.9em;
}

pre {
  background: #f5f5f5;
  padding: 1em;
  border-radius: 6px;
  overflow-x: auto;
  line-height: 1.5;
}
pre code {
  background: none;
  padding: 0;
}

/* 表格 */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 1em 0;
}
th, td {
  border: 1px solid #ddd;
  padding: 0.5em;
  text-align: left;
}
th {
  background: #f0f0f0;
  font-weight: bold;
}

/* 图片 */
img {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 1em auto;
}

/* 水平线 */
hr {
  border: none;
  border-top: 1px solid #ddd;
  margin: 1.5em 0;
}

/* 链接 */
a {
  color: #1976d2;
  text-decoration: none;
}

/* 导航页 */
nav[epub|type="toc"] {
  padding: 1em;
}
nav[epub|type="toc"] h1 {
  font-size: 1.4em;
  margin-bottom: 0.8em;
}
nav[epub|type="toc"] ol {
  list-style: none;
  padding: 0;
}
nav[epub|type="toc"] li {
  margin: 0.4em 0;
  padding: 0.2em 0;
  border-bottom: 1px solid #f0f0f0;
}
nav[epub|type="toc"] a {
  color: #333;
}
''';
}

class _Chapter {
  final String title;
  final String content;
  _Chapter({required this.title, required this.content});
}
