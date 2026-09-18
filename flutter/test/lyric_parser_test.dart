import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beans_music_flutter/model/lyric_style.dart';
import 'package:beans_music_flutter/service/cover_palette.dart';
import 'package:beans_music_flutter/service/lyric_service.dart';
import 'package:beans_music_flutter/store/lyric_style_store.dart';

void main() {
  group('LyricParser', () {
    test('解析基础时间轴并按时间排序', () {
      final lines = LyricParser.parse(
        '[00:10.00]第二行\n[00:02.50]第一行\n[00:20.00]第三行',
      );
      expect(lines.map((line) => line.text).toList(), ['第一行', '第二行', '第三行']);
      expect(lines.first.time, const Duration(seconds: 2, milliseconds: 500));
    });

    test('一行多个时间戳会拆成多行', () {
      final lines = LyricParser.parse('[00:01.00][00:05.00]重复副歌');
      expect(lines.length, 2);
      expect(lines[0].time, const Duration(seconds: 1));
      expect(lines[1].time, const Duration(seconds: 5));
      expect(lines.every((line) => line.text == '重复副歌'), isTrue);
    });

    test('毫秒位数按实际位数换算', () {
      final lines = LyricParser.parse(
        '[00:01.5]a\n[00:02.50]b\n[00:03.500]c',
      );
      expect(lines[0].time, const Duration(milliseconds: 1500));
      expect(lines[1].time, const Duration(milliseconds: 2500));
      expect(lines[2].time, const Duration(milliseconds: 3500));
    });

    test('支持 [offset:] 声明式偏移（毫秒，可为负）', () {
      expect(LyricParser.declaredOffsetSeconds('[offset:-500]'), -0.5);
      expect(LyricParser.declaredOffsetSeconds('[offset:1000]'), 1);

      final lines = LyricParser.parse('[offset:1000]\n[00:02.00]歌词');
      expect(lines.single.time, const Duration(seconds: 3));
    });

    test('忽略元数据行且偏移不会产生负数时间', () {
      final lines = LyricParser.parse(
        '[ti:标题]\n[ar:歌手]\n[offset:0]\n[00:01.00]正文',
      );
      expect(lines.length, 1);
      expect(lines.single.text, '正文');

      final shifted = LyricParser.parse('[offset:-3000]\n[00:01.00]正文');
      expect(shifted.single.time, Duration.zero);
    });

    test('翻译歌词按时间戳合并到对应行', () {
      final lines = LyricParser.parse(
        '[00:01.00]Hello\n[00:05.00]World',
        translationRaw: '[00:01.00]你好\n[00:05.00]世界',
      );
      expect(lines[0].translation, '你好');
      expect(lines[1].translation, '世界');
      expect(lines[1].hasTranslation, isTrue);
    });

    test('空歌词返回空列表', () {
      expect(LyricParser.parse(null), isEmpty);
      expect(LyricParser.parse(''), isEmpty);
      expect(LyricParser.parse('没有任何时间戳的文本'), isEmpty);
    });
  });

  group('LyricTiming', () {
    final lines = LyricParser.parse(
      '[00:00.00]一\n[00:05.00]二\n[00:10.00]三',
    );

    test('effectivePosition 应用用户偏移且不为负', () {
      expect(
        LyricTiming.effectivePosition(const Duration(seconds: 3), 2),
        const Duration(seconds: 5),
      );
      expect(
        LyricTiming.effectivePosition(const Duration(seconds: 1), -5),
        Duration.zero,
      );
    });

    test('seekPosition 与偏移互逆', () {
      expect(
        LyricTiming.seekPosition(lines[1], 2),
        const Duration(seconds: 3),
      );
      expect(
        LyricTiming.seekPosition(lines[0], 5),
        Duration.zero,
      );
      expect(
        LyricTiming.seekPosition(lines[1], -2),
        const Duration(seconds: 7),
      );
    });

    test('currentIndex 二分查找当前行', () {
      expect(LyricTiming.currentIndex(lines, Duration.zero), 0);
      expect(LyricTiming.currentIndex(lines, const Duration(seconds: 7)), 1);
      expect(LyricTiming.currentIndex(lines, const Duration(minutes: 1)), 2);
      expect(
        LyricTiming.currentIndex(lines, const Duration(seconds: -1)),
        isNull,
      );
    });
  });

  group('Lyrics 兜底文案', () {
    test('纯音乐与失败原因', () {
      expect(
        const Lyrics(lines: [], raw: '此歌曲为没有填词的纯音乐，请欣赏').emptyMessage,
        '纯音乐，请欣赏',
      );
      expect(const Lyrics(lines: []).emptyMessage, '暂无歌词');
      expect(
        const Lyrics(lines: [], error: '歌词获取失败：网络').emptyMessage,
        '歌词获取失败：网络',
      );
    });
  });

  group('颜色工具', () {
    test('colorFromHex 支持 #RRGGBB / #AARRGGBB / 省略 #', () {
      expect(colorFromHex('#FF0000'), const Color(0xFFFF0000));
      expect(colorFromHex('00FF00'), const Color(0xFF00FF00));
      expect(colorFromHex('#8000FF00'), const Color(0x8000FF00));
      expect(colorFromHex(''), isNull);
      expect(colorFromHex('xyz'), isNull);
    });

    test('hexFromColor 与 mixColors', () {
      expect(hexFromColor(const Color(0xFF123456)), '#123456');
      final mixed = mixColors(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        0.5,
      );
      expect(mixed.r, closeTo(0.5, 0.001));
      expect(mixed.g, closeTo(0.5, 0.001));
      expect(mixed.b, closeTo(0.5, 0.001));
      expect(
        mixColors(const Color(0xFF000000), const Color(0xFFFFFFFF), 0).r,
        closeTo(0, 0.001),
      );
    });

    test('LyricPreset 颜色可解析', () {
      for (final preset in LyricPreset.all) {
        expect(colorFromHex(preset.startHex), isNotNull);
        expect(colorFromHex(preset.endHex), isNotNull);
        expect(preset.glowLevel, inInclusiveRange(0, 3));
      }
    });
  });

  group('LyricStyleStore', () {
    late SharedPreferences prefs;
    late LyricStyleStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = LyricStyleStore(prefs);
    });

    test('默认值', () {
      expect(store.fontSize, LyricStyleStore.defaultFontSize);
      expect(store.lineSpacing, LyricStyleStore.defaultLineSpacing);
      expect(store.translationEnabled, isTrue);
      expect(store.keepCustomColors, isFalse);
      expect(store.glowLabel, '柔和');
      expect(store.offsetLabel, '同步');
      expect(store.anchorFactor, closeTo(0.5, 0.001));
      expect(store.backgroundLabel, '跟随页面背景');
    });

    test('超出范围的设置会被夹紧并持久化', () async {
      store.fontSize = 100;
      expect(store.fontSize, LyricStyleStore.maxFontSize);
      expect(prefs.getDouble('lyric_font_size'), LyricStyleStore.maxFontSize);

      store.anchorY = 500;
      expect(store.anchorY, LyricStyleStore.maxAnchorY);
      expect(store.anchorFactor, closeTo(0.85, 0.001));

      store.glowLevel = 9;
      expect(store.glowLabel, '强烈');

      final restored = LyricStyleStore(prefs);
      expect(restored.fontSize, LyricStyleStore.maxFontSize);
    });

    test('歌词偏移文案', () {
      store.offsetSeconds = 1.5;
      expect(store.offsetLabel, '提前 1.5s');
      store.offsetSeconds = -2;
      expect(store.offsetLabel, '延后 2.0s');
    });

    test('配色解析：关闭自定义配色时跟随封面取色', () {
      final palette = CoverPalette.make(
        dominant: const RgbColor(0.85, 0.35, 0.25),
        scheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE5654B)),
      );
      expect(store.currentColor(palette), palette.accent);
      expect(store.dimColor(palette), palette.secondary);
      expect(store.gradientStart(palette), palette.accent);
      expect(store.glowColor(palette), palette.accent);

      store.keepCustomColors = true;
      store.currentColorHex = '#123456';
      expect(store.currentColor(palette), const Color(0xFF123456));
      expect(
        store.gradientEnd(palette, Brightness.light),
        mixColors(const Color(0xFF123456), Colors.black, 0.45),
      );
    });

    test('应用渐变预设会开启自定义配色', () {
      final preset = LyricPreset.all.first;
      store.applyPreset(preset);
      expect(store.gradStartHex, preset.startHex);
      expect(store.gradEndHex, preset.endHex);
      expect(store.glowLevel, preset.glowLevel);
      expect(store.keepCustomColors, isTrue);
    });

    test('重置方法恢复默认值', () {
      store.fontSize = 24;
      store.offsetSeconds = 3;
      store.tilt = 20;
      store.currentColorHex = '#ABCDEF';
      store.keepCustomColors = true;
      store.backgroundColorHex = '#000000';
      store.backgroundSyncCover = true;

      store.resetAll();

      expect(store.fontSize, LyricStyleStore.defaultFontSize);
      expect(store.offsetSeconds, 0);
      expect(store.tilt, 0);
      expect(store.currentColorHex, '');
      expect(store.keepCustomColors, isFalse);
      expect(store.backgroundColorHex, '');
      expect(store.backgroundSyncCover, isFalse);
    });
  });

  group('PaletteExtractor', () {
    Uint8List fillPixels(
      int size, {
      required Color color,
      Map<int, Color> overrides = const {},
    }) {
      final pixels = Uint8List(size * size * 4);
      for (var i = 0; i < size * size; i++) {
        final value = overrides[i] ?? color;
        pixels[i * 4] = (value.r * 255).round();
        pixels[i * 4 + 1] = (value.g * 255).round();
        pixels[i * 4 + 2] = (value.b * 255).round();
        pixels[i * 4 + 3] = (value.a * 255).round();
      }
      return pixels;
    }

    test('提取主要色相簇的平均色', () {
      final pixels = fillPixels(
        8,
        color: const Color(0xFFCC3322),
        overrides: {
          0: const Color(0xFFFFFFFF),
          1: const Color(0xFF000000),
        },
      );
      final color = PaletteExtractor.dominantColorFromPixels(
        pixels,
        width: 8,
        height: 8,
      );
      expect(color, isNotNull);
      expect(color!.r, closeTo(0.8, 0.1));
      expect(color.b, closeTo(0.13, 0.1));
    });

    test('全黑 / 全白图片返回 null', () {
      final black = fillPixels(4, color: const Color(0xFF000000));
      expect(
        PaletteExtractor.dominantColorFromPixels(black, width: 4, height: 4),
        isNull,
      );
      final white = fillPixels(4, color: const Color(0xFFFFFFFF));
      expect(
        PaletteExtractor.dominantColorFromPixels(white, width: 4, height: 4),
        isNull,
      );
    });

    test('RgbColor HSL 往返转换', () {
      const original = RgbColor(0.2, 0.6, 0.9);
      final hsl = original.toHsl();
      final restored = RgbColor.fromHsl(h: hsl.h, s: hsl.s, l: hsl.l);
      expect(restored.r, closeTo(original.r, 0.001));
      expect(restored.g, closeTo(original.g, 0.001));
      expect(restored.b, closeTo(original.b, 0.001));
    });
  });
}