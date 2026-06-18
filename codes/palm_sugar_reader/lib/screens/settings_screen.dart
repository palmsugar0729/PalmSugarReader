import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/bookmark_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _settings = await SettingsService.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    await SettingsService.save(_settings);
    // 同步到全局 notifier
    if (mounted) {
      final notifier = SettingsProvider.of(context);
      notifier.setThemeMode(_settings.themeMode);
      notifier.setFontSize(_settings.fontSize);
    }
  }

  // ── 批量导入开关 ──
  Widget _buildBatchImport() {
    return SwitchListTile(
      title: const Text('批量导入'),
      subtitle: const Text('打开文件时自动发现同目录可读文件'),
      value: _settings.batchImport,
      onChanged: (v) {
        setState(() => _settings.batchImport = v);
        _save();
      },
      activeTrackColor: AppTheme.primaryDark,
    );
  }

  // ── 字体大小 ──
  Widget _buildFontSize() {
    return ListTile(
      title: const Text('默认字体大小'),
      subtitle: Text(_fontSizeLabel(_settings.fontSize)),
      trailing: SegmentedButton<double>(
        segments: const [
          ButtonSegment(value: 14, label: Text('小')),
          ButtonSegment(value: 18, label: Text('中')),
          ButtonSegment(value: 24, label: Text('大')),
        ],
        selected: {_settings.fontSize},
        onSelectionChanged: (v) {
          setState(() => _settings.fontSize = v.first);
          _save();
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  String _fontSizeLabel(double size) {
    return switch (size) {
      14 => '小 (14px)',
      18 => '中 (18px)',
      24 => '大 (24px)',
      _ => '${size.round()}px',
    };
  }

  // ── 背景色 ──
  Widget _buildThemeMode() {
    return ListTile(
      title: const Text('背景色'),
      subtitle: Text(_themeModeLabel(_settings.themeMode)),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('浅色'),
            icon: Icon(Icons.light_mode, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('暗色'),
            icon: Icon(Icons.dark_mode, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('系统'),
            icon: Icon(Icons.settings_brightness, size: 16),
          ),
        ],
        selected: {_settings.themeMode},
        onSelectionChanged: (v) {
          setState(() => _settings.themeMode = v.first);
          _save();
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '暗色',
      ThemeMode.system => '跟随系统',
    };
  }

  // ── 额外字体导入 ──
  Widget _buildFontImport() {
    return ListTile(
      leading: const Icon(Icons.font_download_outlined),
      title: const Text('额外字体导入'),
      subtitle: Text(
        _settings.extraFonts.isEmpty
            ? '未导入额外字体'
            : '已导入 ${_settings.extraFonts.length} 个字体',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _importFont,
    );
  }

  Future<void> _importFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
      allowMultiple: true,
    );

    if (result == null) return;

    for (final file in result.files) {
      if (file.path != null && !_settings.extraFonts.contains(file.path!)) {
        _settings.extraFonts.add(file.path!);
      }
    }

    setState(() {});
    _save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 ${result.files.length} 个字体文件'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    }
  }

  // ── 语言入口（占位） ──
  Widget _buildLanguage() {
    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('语言'),
      subtitle: const Text('中文'),
      trailing: const Icon(Icons.chevron_right),
      enabled: false,
      onTap: () {}, // 占位
    );
  }

  // ── 帮助和支持 ──
  Widget _buildHelp() {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: const Text('帮助和支持'),
      subtitle: const Text('版本信息、常见问题'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showAbout,
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.menu_book, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('PalmSugarReader'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: v0.3 MVP'),
            SizedBox(height: 8),
            Text('轻量跨平台综合阅读器'),
            SizedBox(height: 4),
            Text('支持 PDF、EPUB、TXT、Markdown、图片'),
            SizedBox(height: 16),
            Text(
              '开源许可',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('Noto Sans SC — SIL Open Font License'),
            Text('epubx — MIT License'),
            Text('flutter_html — MIT License'),
            Text('pdfrx — MIT License'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // ── 清除历史 ──
  Widget _buildClearHistory() {
    return ListTile(
      leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
      title: const Text('清除历史记录'),
      subtitle: const Text('清空书签和最近文件列表'),
      onTap: _confirmClear,
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('将清空所有书签和最近文件记录，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await BookmarkService.clear();
              await SettingsService.clear();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清除所有历史记录')),
                );
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ── 阅读设置 ──
          _sectionHeader('阅读设置'),
          _buildBatchImport(),
          _buildFontSize(),
          const Divider(),

          // ── 外观 ──
          _sectionHeader('外观'),
          _buildThemeMode(),
          const Divider(),

          // ── 字体 ──
          _sectionHeader('字体'),
          _buildFontImport(),
          const Divider(),

          // ── 通用 ──
          _sectionHeader('通用'),
          _buildLanguage(),
          _buildHelp(),
          const Divider(),

          // ── 数据 ──
          _sectionHeader('数据'),
          _buildClearHistory(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryDark,
        ),
      ),
    );
  }
}
