import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart' as epubx;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../main.dart';
import '../models/annotation.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';
import '../widgets/annotation_layer.dart';
import '../widgets/color_picker.dart';

// ─── 内部数据模型 ────────────────────────────────────────────────────────────

/// 扁平化后的章节目录条目
class _FlatChapter {
  final String title;
  final epubx.EpubChapterRef ref;
  final int depth; // 0 = 顶级, 1+ = 子章节

  const _FlatChapter({
    required this.title,
    required this.ref,
    required this.depth,
  });
}

/// 一页的内容范围
class _PageSpan {
  final int startSegment;
  final int endSegment; // exclusive

  const _PageSpan(this.startSegment, this.endSegment);
}

/// 单个章节的分页结果
class _PaginatedChapter {
  final List<_PageSpan> pages;
  final String cssStyles;
  final List<dom.Element> segments;

  const _PaginatedChapter({
    required this.pages,
    required this.cssStyles,
    required this.segments,
  });
}

// ─── EPUB 翻页阅读器 ─────────────────────────────────────────────────────────

class EpubReader extends StatefulWidget {
  final String filePath;

  const EpubReader({super.key, required this.filePath});

  @override
  State<EpubReader> createState() => EpubReaderState();
}

class EpubReaderState extends State<EpubReader> {
  // ── 懒加载书引用 ──
  epubx.EpubBookRef? _bookRef;
  final List<_FlatChapter> _flatChapters = [];
  int _currentChapterIndex = 0;

  // ── 分页缓存 ──
  final Map<int, _PaginatedChapter> _pageCache = {};

  // ── 翻页控制 ──
  PageController? _pageController;
  int _totalPages = 0;
  int _currentGlobalPage = 0;

  // ── UI 状态 ──
  bool _isLoadingMetadata = true;
  bool _isLoadingContent = false;
  String? _error;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── 标注 ──
  bool _annotMode = false;
  AnnotationType _annotTool = AnnotationType.highlight;
  Color _annotColor = const Color(0xFFFFEB3B);
  double _annotOpacity = 0.4;
  double _annotThickness = 8;

  // ── 进度持久化 ──
  Timer? _progressSaveTimer;

  // ── 视口尺寸（用于分页高度估算） ──
  double _viewportWidth = 400;
  double _viewportHeight = 600;

  // ── 字号（从全局设置读取） ──
  double _fontSize = 18;

  // ── 常量 ──
  static const double _pageFillRatio = 0.85;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _progressSaveTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第一步：快速加载元数据 + TOC
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _loadEpub() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // openBook() 只解析元数据 + TOC，不加载章节 HTML，约 100ms
      _bookRef = await epubx.EpubReader.openBook(bytes);

      // 获取扁平化章节目录
      final chapterRefs = await _bookRef!.getChapters();
      _flattenChapters(chapterRefs, 0);

      // 恢复上次阅读位置
      await _restoreProgress();

      // 如果还没有 pageController（没有历史进度），创建一个
      _pageController ??= PageController(initialPage: 0);
      _totalPages = _flatChapters.length; // 初始估算：每章 1 页

      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
      }

      // 加载当前章节内容
      _loadChapter(_currentChapterIndex);
      // annotations are loaded per-page by AnnotationLayer
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingMetadata = false;
        });
      }
    }
  }

  /// 递归扁平化章节树
  void _flattenChapters(List<epubx.EpubChapterRef> refs, int depth) {
    for (final ref in refs) {
      final title = ref.Title?.replaceAll('\n', ' ').trim() ?? '(无标题)';
      _flatChapters.add(_FlatChapter(
        title: title.isEmpty ? '(无标题)' : title,
        ref: ref,
        depth: depth,
      ));
      if (ref.SubChapters != null && ref.SubChapters!.isNotEmpty) {
        _flattenChapters(ref.SubChapters!, depth + 1);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第二步：按需加载章节 HTML + 分页
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _loadChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;
    if (_pageCache.containsKey(chapterIndex)) return; // 已缓存

    setState(() => _isLoadingContent = true);

    try {
      final chapterRef = _flatChapters[chapterIndex].ref;
      final html = await chapterRef.readHtmlContent();
      _paginateChapter(chapterIndex, html);
    } catch (e) {
      // 加载失败：创建空页占位
      _pageCache[chapterIndex] = _PaginatedChapter(
        pages: [const _PageSpan(0, 1)],
        cssStyles: '',
        segments: [
          dom.Element.tag('p')
            ..nodes.add(dom.Text('章节加载失败: ${e.toString()}')),
        ],
      );
    }

    _recalcTotalPages();

    if (mounted) {
      setState(() => _isLoadingContent = false);
    }
  }

  /// 解析 HTML → 分页 → 缓存
  void _paginateChapter(int chapterIndex, String rawHtml) {
    // 1. 解析 HTML
    final document = html_parser.parse(rawHtml);
    final body = document.body;
    if (body == null) {
      _pageCache[chapterIndex] = _PaginatedChapter(
        pages: [const _PageSpan(0, 0)],
        cssStyles: '',
        segments: [],
      );
      return;
    }

    // 2. 提取 <style> 块
    final styleElements = document.getElementsByTagName('style');
    final cssStyles = styleElements.map((e) => e.innerHtml).join('\n');

    // 3. 展平 body 子节点
    final flatNodes = _flattenNodes(body.nodes.toList());

    // 4. 切片为可渲染的 Element 列表
    final segments = _segmentNodes(flatNodes);

    // 5. 按视口高度分页
    final pages = _buildPages(segments);

    _pageCache[chapterIndex] = _PaginatedChapter(
      pages: pages,
      cssStyles: cssStyles,
      segments: segments,
    );
  }

  // ── 展平：展开 div/section/span，保留 p/h1-h6/img/blockquote 等 ──
  List<dom.Node> _flattenNodes(List<dom.Node> nodes) {
    final result = <dom.Node>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) result.add(node);
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (tag == 'div' || tag == 'section' || tag == 'article' || tag == 'span') {
          result.addAll(_flattenNodes(node.nodes.toList()));
        } else {
          result.add(node);
        }
      }
    }
    return result;
  }

  // ── 切片：独立文本节点包裹为 <p> ──
  List<dom.Element> _segmentNodes(List<dom.Node> nodes) {
    final segments = <dom.Element>[];
    dom.Element? pendingWrapper;

    void flushPending() {
      if (pendingWrapper != null && pendingWrapper!.nodes.isNotEmpty) {
        segments.add(pendingWrapper!);
        pendingWrapper = null;
      }
    }

    for (final node in nodes) {
      if (node is dom.Element) {
        flushPending();
        segments.add(node);
      } else if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isEmpty) continue;
        pendingWrapper ??= dom.Element.tag('p');
        pendingWrapper!.nodes.add(dom.Text(text));
      }
    }
    flushPending();
    return segments;
  }

  // ── 估算单个元素的高度（单位：逻辑像素） ──
  double _estimateElementHeight(dom.Element element) {
    final tag = element.localName?.toLowerCase() ?? '';
    final text = element.text;
    final textLen = text.length;
    final charsPerLine =
        (_viewportWidth / (_fontSize * 0.55)).floor().clamp(1, 200);
    final baseLines = (textLen / charsPerLine).ceil();
    final lineHeight = _fontSize * 1.5;

    switch (tag) {
      case 'h1':
        return lineHeight * 2.5 + 32;
      case 'h2':
        return lineHeight * 2.0 + 24;
      case 'h3':
        return lineHeight * 1.7 + 20;
      case 'h4':
      case 'h5':
      case 'h6':
        return lineHeight * 1.4 + 16;
      case 'img':
        return 180; // 占位高度
      case 'hr':
        return 24;
      case 'br':
        return lineHeight;
      case 'table':
        return (textLen / charsPerLine * 0.7).ceil() * lineHeight + 24;
      case 'blockquote':
        return baseLines * lineHeight + 24;
      case 'li':
        return baseLines * lineHeight + 4;
      case 'pre':
        return baseLines * lineHeight + 16;
      case 'svg':
        return 120;
      default:
        return baseLines * lineHeight + 8; // p, div 等
    }
  }

  // ── 按视口高度将元素切分为页 ──
  List<_PageSpan> _buildPages(List<dom.Element> segments) {
    final pages = <_PageSpan>[];
    final maxPageHeight = _viewportHeight * _pageFillRatio;

    int startIdx = 0;
    double currentHeight = 0;

    for (int i = 0; i < segments.length; i++) {
      final elemHeight = _estimateElementHeight(segments[i]);

      if (currentHeight + elemHeight > maxPageHeight && i > startIdx) {
        pages.add(_PageSpan(startIdx, i));
        startIdx = i;
        currentHeight = elemHeight;
      } else {
        currentHeight += elemHeight;
      }
    }

    // 最后一页
    if (startIdx < segments.length) {
      pages.add(_PageSpan(startIdx, segments.length));
    }

    return pages.isEmpty ? [const _PageSpan(0, 0)] : pages;
  }

  // ── 重新计算全书总页数 ──
  void _recalcTotalPages() {
    int total = 0;
    for (int i = 0; i < _flatChapters.length; i++) {
      total += _pageCache[i]?.pages.length ?? 1; // 未加载的章节默认 1 页
    }
    if (total != _totalPages) {
      _totalPages = total;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第三步：渲染单页内容
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildPage(BuildContext context, int globalPage) {
    // 查找 globalPage 对应的章节和页内偏移
    final (chapterIndex, pageInChapter) = _resolveGlobalPage(globalPage);

    // 未加载的章节：触发加载，显示 loading
    if (!_pageCache.containsKey(chapterIndex)) {
      _loadChapter(chapterIndex);
      return const Center(child: CircularProgressIndicator());
    }

    final paginated = _pageCache[chapterIndex]!;
    if (paginated.pages.isEmpty || paginated.segments.isEmpty) {
      return Center(
        child: Text(
          '(空章节)',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    final span = pageInChapter < paginated.pages.length
        ? paginated.pages[pageInChapter]
        : paginated.pages.last;

    final pageSegments = paginated.segments.sublist(
      span.startSegment,
      span.endSegment.clamp(span.startSegment, paginated.segments.length),
    );

    if (pageSegments.isEmpty) {
      return const SizedBox.shrink();
    }

    // 每页用 SingleChildScrollView 包裹作为溢出安全网，外层叠 AnnotationLayer
    return AnnotationLayer(
      filePath: widget.filePath,
      pageIndex: globalPage,
      enabled: _annotMode,
      tool: _annotTool,
      color: _annotColor,
      opacity: _annotOpacity,
      thickness: _annotThickness,
      onClose: _exitAnnotMode,
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pageSegments.map((element) {
          // 克隆元素，注入内联 CSS
          final cloned = _cloneElementWithStyles(element, paginated.cssStyles);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: double.infinity,
              child: Html.fromElement(
                documentElement: cloned,
                style: _readerStyles(),
              ),
            ),
          );
        }).toList(),
      ),
    ),
    );
  }

  /// 克隆元素并注入 <style> 包装
  dom.Element _cloneElementWithStyles(dom.Element source, String cssStyles) {
    final wrapper = dom.Element.tag('div');
    if (cssStyles.isNotEmpty) {
      final styleEl = dom.Element.tag('style');
      styleEl.nodes.add(dom.Text(cssStyles));
      wrapper.nodes.add(styleEl);
    }
    wrapper.nodes.add(source.clone(true) as dom.Node);
    return wrapper;
  }

  /// 阅读器通用样式
  Map<String, Style> _readerStyles() {
    return {
      'body': Style(
        fontSize: FontSize(_fontSize),
        lineHeight: const LineHeight(1.6),
        padding: HtmlPaddings.zero,
        margin: Margins.zero,
        color: AppTheme.textPrimary,
      ),
      'p': Style(
        fontSize: FontSize(_fontSize),
        lineHeight: const LineHeight(1.6),
        margin: Margins.only(bottom: 8),
      ),
      'h1': Style(
        fontSize: FontSize(_fontSize * 1.8),
        lineHeight: const LineHeight(1.3),
        margin: Margins.only(top: 16, bottom: 12),
        fontWeight: FontWeight.bold,
      ),
      'h2': Style(
        fontSize: FontSize(_fontSize * 1.5),
        lineHeight: const LineHeight(1.3),
        margin: Margins.only(top: 14, bottom: 10),
        fontWeight: FontWeight.bold,
      ),
      'h3': Style(
        fontSize: FontSize(_fontSize * 1.3),
        lineHeight: const LineHeight(1.3),
        margin: Margins.only(top: 12, bottom: 8),
        fontWeight: FontWeight.w600,
      ),
      'blockquote': Style(
        fontSize: FontSize(_fontSize),
        fontStyle: FontStyle.italic,
        border: Border(left: BorderSide(color: AppTheme.primaryColor, width: 3)),
        padding: HtmlPaddings.only(left: 12),
        margin: Margins.only(top: 8, bottom: 8),
      ),
      'img': Style(
        margin: Margins.only(top: 8, bottom: 8),
      ),
    };
  }

  // ── 将 globalPage 映射到 (chapterIndex, pageInChapter) ──
  (int, int) _resolveGlobalPage(int globalPage) {
    int remaining = globalPage;
    for (int i = 0; i < _flatChapters.length; i++) {
      final pagesInChapter = _pageCache[i]?.pages.length ?? 1;
      if (remaining < pagesInChapter) {
        return (i, remaining);
      }
      remaining -= pagesInChapter;
    }
    // 超出范围，返回最后一章最后一页
    final lastIdx = _flatChapters.length - 1;
    return (lastIdx, (_pageCache[lastIdx]?.pages.length ?? 1) - 1);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第四步：翻页处理 + 进度保存
  // ════════════════════════════════════════════════════════════════════════════

  void _onPageChanged(int newGlobalPage) {
    if (newGlobalPage == _currentGlobalPage) return;

    _currentGlobalPage = newGlobalPage;

    // 判断当前章节是否改变
    final (chapterIndex, _) = _resolveGlobalPage(newGlobalPage);
    _currentChapterIndex = chapterIndex;

    // 预加载相邻章节
    _preloadAdjacent(chapterIndex);

    // 触发 UI 更新（章节标题、页码等）
    setState(() {});

    // 保存进度（300ms 防抖）
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(milliseconds: 300), () {
      _saveProgress();
    });
  }

  void _preloadAdjacent(int chapterIndex) {
    // 后一章
    if (chapterIndex + 1 < _flatChapters.length &&
        !_pageCache.containsKey(chapterIndex + 1)) {
      _loadChapter(chapterIndex + 1);
    }
    // 前一章
    if (chapterIndex - 1 >= 0 &&
        !_pageCache.containsKey(chapterIndex - 1)) {
      _loadChapter(chapterIndex - 1);
    }
  }

  Future<void> _saveProgress() async {
    if (_totalPages <= 0 || _flatChapters.isEmpty) return;

    final position =
        (_currentGlobalPage / (_totalPages - 1).clamp(1, 999999))
            .clamp(0.0, 1.0);

    await BookmarkService.updateProgress(widget.filePath, position);
  }

  Future<void> _restoreProgress() async {
    if (_flatChapters.isEmpty) return;

    try {
      final bookmarks = await BookmarkService.loadBookmarks();
      for (final bm in bookmarks) {
        if (bm.filePath == widget.filePath && bm.lastPosition != null) {
          final pos = bm.lastPosition!;
          // 用章节数做粗粒度估算：pos 对应到章节索引
          _currentChapterIndex =
              (pos * (_flatChapters.length - 1)).round().clamp(
                    0,
                    _flatChapters.length - 1,
                  );
          return;
        }
      }
    } catch (_) {
      // 恢复失败，从第一章开始
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第五步：导航方法
  // ════════════════════════════════════════════════════════════════════════════

  void _goToNextPage() {
    if (_currentGlobalPage < _totalPages - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrevPage() {
    if (_currentGlobalPage > 0) {
      _pageController?.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── 标注模式 ──

  void enterAnnotationMode() async {
    final type = await showDialog<AnnotationType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择标注类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.highlight),
            child: const ListTile(leading: Icon(Icons.format_paint, color: Color(0xFFFFEB3B)), title: Text('高亮')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.underline),
            child: const ListTile(leading: Icon(Icons.format_underlined, color: Color(0xFF2196F3)), title: Text('划线')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AnnotationType.note),
            child: const ListTile(leading: Icon(Icons.notes, color: Color(0xFF4CAF50)), title: Text('批注')),
          ),
        ],
      ),
    );
    if (type == null || !mounted) return;

    final style = await AnnotationColorPicker.show(context);
    if (style == null || !mounted) return;

    setState(() {
      _annotMode = true;
      _annotTool = type;
      _annotColor = style.color;
      _annotOpacity = style.opacity;
      _annotThickness = style.thickness;
    });
  }

  void _exitAnnotMode() => setState(() => _annotMode = false);

  // ── 导航 ──

  void _goToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;

    // 计算该章首页的 globalPage
    int globalPage = 0;
    for (int i = 0; i < chapterIndex; i++) {
      globalPage += _pageCache[i]?.pages.length ?? 1;
    }

    _pageController?.animateToPage(
      globalPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    Navigator.pop(context); // 关闭 drawer
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 第六步：UI 构建
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetadata) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在解析 EPUB 结构...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('读取失败')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'EPUB 加载失败\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNextPage,
        const SingleActivator(LogicalKeyboardKey.home): () {
          if (_pageController?.hasClients == true) _pageController!.jumpToPage(0);
        },
        const SingleActivator(LogicalKeyboardKey.end): () {
          if (_pageController?.hasClients == true) _pageController!.jumpToPage(_totalPages - 1);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: _buildTocDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = constraints.maxWidth;
          _viewportHeight = constraints.maxHeight;
          _fontSize = SettingsProvider.of(context).fontSize;

          return Column(
            children: [
              // 顶部导航栏（章节标题 + 页码）
              _buildTopBar(context),

              // 翻页阅读区
              Expanded(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTapUp: (details) {
                        // 点击左/右区域翻页
                        final dx = details.localPosition.dx;
                        if (dx < _viewportWidth * 0.3) {
                          _goToPrevPage();
                        } else if (dx > _viewportWidth * 0.7) {
                          _goToNextPage();
                        }
                      },
                      onLongPress: enterAnnotationMode,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _totalPages.clamp(1, 999999),
                        scrollDirection: Axis.horizontal,
                        pageSnapping: true,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) =>
                            _buildPage(context, index),
                      ),
                    ),

                    // 章节加载中指示器
                    if (_isLoadingContent)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
              ),

              // 底部页码信息
              _buildBottomBar(),
            ],
          );
        },
      ),
    ),
    ),
  );
}

Widget _buildTopBar(BuildContext context) {
  final chapterTitle =
        _currentChapterIndex < _flatChapters.length
            ? _flatChapters[_currentChapterIndex].title
            : '';

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            tooltip: '返回书架',
            onPressed: () => Navigator.pop(context),
          ),
          // 章节标题
          Expanded(
            child: Text(
              chapterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // TOC 目录按钮
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white, size: 22),
            tooltip: '章节目录',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    // 计算当前章节内的页码
    final (chIdx, pageInCh) = _resolveGlobalPage(_currentGlobalPage);
    final chPages = _pageCache[chIdx]?.pages.length ?? 1;
    final chPageDisplay = '${pageInCh + 1} / $chPages';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.primaryLight.withAlpha(80)),
        ),
      ),
      child: Row(
        children: [
          // 上一页
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _goToPrevPage,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: _currentGlobalPage > 0
                    ? AppTheme.primaryDark
                    : AppTheme.textSecondary.withAlpha(80),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 章节内页码 + 全书进度
          Expanded(
            child: Text(
              '$chPageDisplay   总进度 ${((_currentGlobalPage + 1) / _totalPages * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 下一页
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _goToNextPage,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: _currentGlobalPage < _totalPages - 1
                    ? AppTheme.primaryDark
                    : AppTheme.textSecondary.withAlpha(80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 章节目录抽屉 ──
  Widget _buildTocDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 抽屉头部
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bookRef?.Title ?? '章节目录',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_bookRef?.Author != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _bookRef!.Author!,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 章节列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _flatChapters.length,
                itemBuilder: (context, index) {
                  final chapter = _flatChapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16 + chapter.depth * 16.0,
                      right: 16,
                    ),
                    leading: Icon(
                      isCurrent ? Icons.bookmark : Icons.article_outlined,
                      size: 18,
                      color:
                          isCurrent ? AppTheme.primaryDark : AppTheme.textSecondary,
                    ),
                    title: Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isCurrent ? AppTheme.primaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    tileColor:
                        isCurrent ? AppTheme.primaryLight.withAlpha(40) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onTap: () => _goToChapter(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
