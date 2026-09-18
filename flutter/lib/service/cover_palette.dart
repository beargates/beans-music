import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 0~1 RGB 颜色（封面取色的中间表示，对应 Swift `RGBColor`）。
class RgbColor {
  final double r;
  final double g;
  final double b;

  const RgbColor(this.r, this.g, this.b);

  Color get color => Color.from(alpha: 1, red: r, green: g, blue: b);

  double get luminance => 0.2126 * r + 0.7152 * g + 0.0722 * b;

  bool get isDark => luminance < 0.5;

  /// HSL 转换（h: 0~360，s/l: 0~1），与 Swift 实现一致
  ({double h, double s, double l}) toHsl() {
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final delta = maxC - minC;
    var h = 0.0;
    if (delta > 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        h = 60 * ((b - r) / delta + 2);
      } else {
        h = 60 * ((r - g) / delta + 4);
      }
    }
    if (h < 0) h += 360;
    final l = (maxC + minC) / 2;
    final s = delta == 0 ? 0.0 : delta / (1 - (2 * l - 1).abs());
    return (h: h, s: s, l: l);
  }

  factory RgbColor.fromHsl({
    required double h,
    required double s,
    required double l,
  }) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final hp = h / 60;
    final x = c * (1 - ((hp % 2) - 1).abs());
    final (double r1, double g1, double b1) = switch (hp.floor()) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    final m = l - c / 2;
    return RgbColor(
      (r1 + m).clamp(0.0, 1.0),
      (g1 + m).clamp(0.0, 1.0),
      (b1 + m).clamp(0.0, 1.0),
    );
  }

  RgbColor withSaturation(double saturation) {
    final hsl = toHsl();
    return RgbColor.fromHsl(
      h: hsl.h,
      s: saturation.clamp(0.0, 1.0),
      l: hsl.l,
    );
  }

  RgbColor withLightness(double lightness) {
    final hsl = toHsl();
    return RgbColor.fromHsl(
      h: hsl.h,
      s: hsl.s,
      l: lightness.clamp(0.0, 1.0),
    );
  }
}

/// 由封面主色生成的动态调色板（播放器 / 歌词跟随封面取色）。
class CoverPalette {
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color accent;
  final Color accentSoft;
  final Color text;
  final Color secondary;

  const CoverPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.secondary,
  });

  /// 无封面 / 提取失败时回退到全局主题色，保证任何场景都有可读配色。
  static CoverPalette fallback(ColorScheme scheme) {
    final accent = scheme.primary;
    return CoverPalette(
      backgroundTop: scheme.surface,
      backgroundBottom: scheme.surface.withValues(alpha: 0.86),
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.28),
      text: scheme.onSurface,
      secondary: scheme.onSurfaceVariant,
    );
  }

  /// 背景降饱和、强调色提饱和、文字按背景亮度自动黑白。
  static CoverPalette make({
    required RgbColor? dominant,
    required ColorScheme scheme,
  }) {
    if (dominant == null) return fallback(scheme);
    final dark = scheme.brightness == Brightness.dark;

    final bgBase = dominant.withSaturation(dark ? 0.26 : 0.32);
    final backgroundTop = bgBase.withLightness(dark ? 0.20 : 0.74);
    final backgroundBottom = bgBase.withLightness(dark ? 0.08 : 0.56);
    final accent = dominant
        .withSaturation(dark ? 0.68 : 0.62)
        .withLightness(dark ? 0.72 : 0.50)
        .color;
    final text = backgroundTop.luminance > 0.52
        ? const Color(0xFF1C1C21)
        : const Color(0xFFFAFAFC);

    return CoverPalette(
      backgroundTop: backgroundTop.color,
      backgroundBottom: backgroundBottom.color,
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.26),
      text: text,
      secondary: text.withValues(alpha: 0.66),
    );
  }
}

/// 主色提取器：把封面缩到 48px 后按色相 16 桶聚类，取最大簇平均色（纯 CPU，极快）。
class PaletteExtractor {
  static RgbColor? dominantColorFromPixels(
    Uint8List pixels, {
    required int width,
    required int height,
  }) {
    const bucketCount = 16;
    final counts = List<int>.filled(bucketCount, 0);
    final weights = List<double>.filled(bucketCount, 0);
    final sumR = List<double>.filled(bucketCount, 0);
    final sumG = List<double>.filled(bucketCount, 0);
    final sumB = List<double>.filled(bucketCount, 0);

    final total = width * height;
    for (var i = 0; i < total; i++) {
      final offset = i * 4;
      if (offset + 3 >= pixels.length) break;
      final alpha = pixels[offset + 3] / 255;
      if (alpha <= 0.85) continue;

      final r = pixels[offset] / 255;
      final g = pixels[offset + 1] / 255;
      final b = pixels[offset + 2] / 255;
      final hsl = RgbColor(r, g, b).toHsl();
      // 过滤纯黑 / 纯白 / 极暗像素，避免污染主色
      if (hsl.l <= 0.09 || hsl.l >= 0.93) continue;

      final bucket = math.min(15, (hsl.h / 360 * bucketCount).floor());
      // 饱和度越高权重越大，避免灰调像素拉低主色
      final weight = 0.30 + hsl.s * 0.70;
      counts[bucket]++;
      weights[bucket] += weight;
      sumR[bucket] += r * weight;
      sumG[bucket] += g * weight;
      sumB[bucket] += b * weight;
    }

    var bestIndex = -1;
    var bestCount = 0;
    for (var i = 0; i < bucketCount; i++) {
      if (counts[i] > bestCount) {
        bestCount = counts[i];
        bestIndex = i;
      }
    }
    if (bestIndex < 0 || bestCount == 0) return null;

    final weightSum = weights[bestIndex];
    if (weightSum <= 0) return null;
    return RgbColor(
      sumR[bestIndex] / weightSum,
      sumG[bestIndex] / weightSum,
      sumB[bestIndex] / weightSum,
    );
  }
}

/// 封面主色提取服务（带内存缓存，避免切歌时重复下载与解码）。
class CoverColorExtractor {
  static const int _targetWidth = 48;

  final Dio dio;
  final Map<String, RgbColor?> _cache = {};
  final Map<String, Future<RgbColor?>> _pending = {};

  CoverColorExtractor({required this.dio});

  /// 已缓存的主色（未提取过返回 null）。
  RgbColor? cachedColor(String? url) {
    if (url == null || url.isEmpty) return null;
    return _cache[url];
  }

  Future<RgbColor?> dominantColor(String? url) {
    if (url == null || url.isEmpty) return Future.value(null);
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    final pending = _pending[url];
    if (pending != null) return pending;

    final future = _extract(url)
        .then<RgbColor?>((value) => value)
        .catchError((Object _) => null)
        .whenComplete(() => _pending.remove(url));
    _pending[url] = future;
    future.then((value) => _cache[url] = value);
    return future;
  }

  void clear() {
    _cache.clear();
    _pending.clear();
  }

  Future<RgbColor?> _extract(String url) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) return null;

    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(bytes),
      targetWidth: _targetWidth,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return null;
        return PaletteExtractor.dominantColorFromPixels(
          data.buffer.asUint8List(),
          width: image.width,
          height: image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}