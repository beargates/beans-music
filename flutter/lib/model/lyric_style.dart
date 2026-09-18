import 'package:flutter/material.dart';

/// 解析 `#RRGGBB` / `#AARRGGBB` 颜色字符串（与 Swift `Color(hex:)` 行为一致）。
Color? colorFromHex(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

/// 颜色转 `#RRGGBB`（忽略透明度，与备用色盘写入格式一致）。
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 按比例混合两色（amount=0 返回 base，1 返回 other）。
Color mixColors(Color base, Color other, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return Color.from(
    alpha: 1,
    red: base.r * (1 - t) + other.r * t,
    green: base.g * (1 - t) + other.g * t,
    blue: base.b * (1 - t) + other.b * t,
  );
}

/// 歌词渐变预设（一键组合：渐变起止色 + 发光强度），与 Swift `LyricPreset` 一致。
class LyricPreset {
  final String name;
  final String startHex;
  final String endHex;
  final int glowLevel;

  const LyricPreset({
    required this.name,
    required this.startHex,
    required this.endHex,
    required this.glowLevel,
  });

  Color get startColor => colorFromHex(startHex) ?? const Color(0xFFF5B045);
  Color get endColor => colorFromHex(endHex) ?? const Color(0xFF8E8E93);

  static const List<LyricPreset> all = [
    LyricPreset(
      name: '晨曦金',
      startHex: '#FFD08A',
      endHex: '#FF7A3D',
      glowLevel: 2,
    ),
    LyricPreset(
      name: '冰蓝极光',
      startHex: '#8FD8FF',
      endHex: '#5B6BFF',
      glowLevel: 2,
    ),
    LyricPreset(
      name: '霓虹紫',
      startHex: '#E8A2FF',
      endHex: '#8A2BE2',
      glowLevel: 3,
    ),
    LyricPreset(
      name: '草莓奶昔',
      startHex: '#FF9AB5',
      endHex: '#FF5E8A',
      glowLevel: 1,
    ),
    LyricPreset(
      name: '金夜曲',
      startHex: '#F5D98B',
      endHex: '#C9A227',
      glowLevel: 2,
    ),
    LyricPreset(
      name: '薄荷气泡',
      startHex: '#A8F0D4',
      endHex: '#2BC48D',
      glowLevel: 2,
    ),
  ];
}

/// 色盘里的一个可选颜色；[hex] 为空表示「跟随封面取色」。
class LyricColorOption {
  final String id;
  final String label;
  final String? hex;

  const LyricColorOption({
    required this.id,
    required this.label,
    this.hex,
  });

  bool get isAuto => hex == null;

  Color resolve(Color fallback) => colorFromHex(hex) ?? fallback;
}

/// 当前行颜色预设（对齐 Swift `beans.lyricColor` 取值）
const List<LyricColorOption> lyricCurrentColorOptions = [
  LyricColorOption(id: 'auto', label: '跟随封面'),
  LyricColorOption(id: 'white', label: '纯白', hex: '#FFFFFF'),
  LyricColorOption(id: 'amber', label: '琥珀', hex: '#F5B045'),
  LyricColorOption(id: 'cyan', label: '天青', hex: '#59D9F5'),
  LyricColorOption(id: 'pink', label: '樱粉', hex: '#FF9ED1'),
  LyricColorOption(id: 'green', label: '薄荷', hex: '#6BE69E'),
];

/// 未播放行颜色预设（对齐 Swift `beans.lyricDimColor` 取值）
const List<LyricColorOption> lyricDimColorOptions = [
  LyricColorOption(id: 'auto', label: '跟随封面'),
  LyricColorOption(id: 'white', label: '白色 78%', hex: '#C7FFFFFF'),
  LyricColorOption(id: 'bluegray', label: '蓝灰', hex: '#B8C7DBFF'),
  LyricColorOption(id: 'gray', label: '中性灰', hex: '#D98E8E93'),
  LyricColorOption(id: 'dark', label: '深灰', hex: '#8C000000'),
];