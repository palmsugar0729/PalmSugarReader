import 'package:flutter/material.dart';
import '../theme.dart';

/// 标注颜色选择器 — 预置色块 + HEX + 不透明度 + 粗细 + 画笔类型
///
/// 返回 (color, opacity, thickness, brushType)，取消返回 null
class AnnotationColorPicker extends StatefulWidget {
  final Color initialColor;
  final double initialOpacity;
  final double initialThickness;
  final int initialBrushType;
  final bool showBrushPicker; // 是否显示画笔类型选择（自由画笔模式）

  const AnnotationColorPicker({
    super.key,
    this.initialColor = const Color(0xFFFFEB3B),
    this.initialOpacity = 0.4,
    this.initialThickness = 8,
    this.initialBrushType = 0,
    this.showBrushPicker = false,
  });

  static Future<({Color color, double opacity, double thickness, int brushType})?> show(
    BuildContext context, {
    Color initialColor = const Color(0xFFFFEB3B),
    double initialOpacity = 0.4,
    double initialThickness = 8,
    int initialBrushType = 0,
    bool showBrushPicker = false,
  }) {
    return showDialog<
        ({Color color, double opacity, double thickness, int brushType})>(
      context: context,
      builder: (_) => AnnotationColorPicker(
        initialColor: initialColor,
        initialOpacity: initialOpacity,
        initialThickness: initialThickness,
        initialBrushType: initialBrushType,
        showBrushPicker: showBrushPicker,
      ),
    );
  }

  @override
  State<AnnotationColorPicker> createState() => _AnnotationColorPickerState();
}

class _AnnotationColorPickerState extends State<AnnotationColorPicker> {
  late Color _color;
  late double _opacity;
  late double _thickness;
  late int _brushType;
  final _hexCtl = TextEditingController();

  static const _presets = [
    Color(0xFFFFEB3B), Color(0xFF4CAF50), Color(0xFF2196F3),
    Color(0xFFE91E63), Color(0xFFFF9800), Color(0xFF000000),
  ];

  static const _brushLabels = ['铅笔', '画笔', '水彩笔'];
  static const _brushIcons = [Icons.edit, Icons.brush, Icons.water_drop];

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _opacity = widget.initialOpacity;
    _thickness = widget.initialThickness;
    _brushType = widget.initialBrushType;
    _hexCtl.text = _colorToHex(_color);
  }

  @override
  void dispose() { _hexCtl.dispose(); super.dispose(); }

  String _colorToHex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  void _onHex(String hex) {
    final t = hex.trim();
    if (t.length == 7 && t.startsWith('#')) {
      try {
        final r = int.parse(t.substring(1, 3), radix: 16);
        final g = int.parse(t.substring(3, 5), radix: 16);
        final b = int.parse(t.substring(5, 7), radix: 16);
        setState(() => _color = Color.fromARGB(255, r, g, b));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('标注设置'),
      content: SizedBox(width: 280, child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 预置色块
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _presets.map((c) {
          final sel = c.toARGB32() == _color.toARGB32();
          return GestureDetector(
            onTap: () { setState(() { _color = c; _hexCtl.text = _colorToHex(c); }); },
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: c.withValues(alpha: _opacity),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppTheme.primaryDark : Colors.grey.shade300, width: sel ? 3 : 1))),
          );
        }).toList()),
        const SizedBox(height: 12),
        // HEX
        Row(children: [
          const Text('HEX:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          SizedBox(width: 90, height: 30,
            child: TextField(controller: _hexCtl, style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  border: OutlineInputBorder(), isDense: true),
              onChanged: _onHex)),
          const SizedBox(width: 8),
          Container(width: 24, height: 24,
            decoration: BoxDecoration(color: _color.withValues(alpha: _opacity),
                borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300))),
        ]),
        const SizedBox(height: 12),
        // 不透明度
        Row(children: [
          const Text('不透明:', style: TextStyle(fontSize: 13)),
          Expanded(child: SliderTheme(
            data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: _color, inactiveTrackColor: Colors.grey.shade200, thumbColor: AppTheme.primaryDark),
            child: Slider(value: _opacity, min: 0.1, max: 1.0, divisions: 9,
                label: '${(_opacity * 100).round()}%', onChanged: (v) => setState(() => _opacity = v))),
          ),
          Text('${(_opacity * 100).round()}%', style: const TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        // 粗细
        Row(children: [
          const Text('粗细:', style: TextStyle(fontSize: 13)),
          Expanded(child: SliderTheme(
            data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: AppTheme.primaryDark, inactiveTrackColor: Colors.grey.shade200, thumbColor: AppTheme.primaryDark),
            child: Slider(value: _thickness, min: 2, max: 40, divisions: 19,
                label: '${_thickness.round()}px', onChanged: (v) => setState(() => _thickness = v))),
          ),
          Text('${_thickness.round()}px', style: const TextStyle(fontSize: 12)),
        ]),
        // 画笔类型选择（仅自由画笔模式显示）
        if (widget.showBrushPicker) ...[
          const SizedBox(height: 12),
          const Text('画笔类型:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(3, (i) {
            final sel = _brushType == i;
            return GestureDetector(
              onTap: () => setState(() => _brushType = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryLight.withAlpha(80) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppTheme.primaryDark : Colors.grey.shade300, width: sel ? 2 : 1),
                ),
                child: Column(children: [
                  Icon(_brushIcons[i], size: 22, color: sel ? AppTheme.primaryDark : Colors.grey.shade500),
                  const SizedBox(height: 2),
                  Text(_brushLabels[i], style: TextStyle(fontSize: 11, color: sel ? AppTheme.primaryDark : Colors.grey.shade500)),
                ]),
              ),
            );
          })),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, (
          color: _color.withValues(alpha: _opacity),
          opacity: _opacity,
          thickness: _thickness,
          brushType: _brushType,
        )), child: const Text('确定')),
      ],
    );
  }
}
