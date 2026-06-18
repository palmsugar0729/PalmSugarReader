import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 应用设置数据模型
class AppSettings {
  bool batchImport;
  double fontSize;
  ThemeMode themeMode;
  String language;
  List<String> extraFonts;

  AppSettings({
    this.batchImport = true,
    this.fontSize = 18,
    this.themeMode = ThemeMode.system,
    this.language = 'zh',
    this.extraFonts = const [],
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      batchImport: json['batchImport'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      themeMode: _themeModeFromString(json['themeMode'] as String?),
      language: json['language'] as String? ?? 'zh',
      extraFonts: (json['extraFonts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'batchImport': batchImport,
        'fontSize': fontSize,
        'themeMode': _themeModeToString(themeMode),
        'language': language,
        'extraFonts': extraFonts,
      };

  static ThemeMode _themeModeFromString(String? s) {
    return switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  static String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

/// 设置持久化服务 — JSON 文件存储
class SettingsService {
  SettingsService._();

  static AppSettings? _cache;

  static Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'settings.json'));
  }

  /// 加载设置
  static Future<AppSettings> load() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file;
      if (!await file.exists()) {
        _cache = AppSettings();
        return _cache!;
      }
      final content = await file.readAsString();
      _cache = AppSettings.fromJson(
        json.decode(content) as Map<String, dynamic>,
      );
      return _cache!;
    } catch (_) {
      _cache = AppSettings();
      return _cache!;
    }
  }

  /// 保存设置
  static Future<void> save(AppSettings settings) async {
    _cache = settings;
    try {
      final file = await _file;
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
        encoding: utf8,
      );
    } catch (_) {
      // 静默失败
    }
  }

  /// 清除所有设置
  static Future<void> clear() async {
    _cache = AppSettings();
    try {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
